module Nanite
  class Agent
    include AMQPHelper
    include FileStreaming
    include ConsoleHelper
    include DaemonizeHelper
    attr_reader :identity, :log, :options, :amq, :serializer, :actors
    attr_accessor :status_proc

    # Initializes a new agent and establishes
    # AMQP connection. 
    # This must be used inside EM.run block or if EventMachine reactor
    # is already started, for instance, by a Thin server that your Merb/Rails
    # application runs on.
    #
    # Agent options:
    #
    # identity    : identity of this agent, may be any string
    #
    # status_proc : a callable object that returns agent load as a string,
    #               defaults to load averages string extracted from `uptime`
    # format      : format to use for packets serialization. One of the two:
    #               :marshall or :json. Defaults to
    #               Ruby's Marshall format. For interoperability with
    #               AMQP clients implemented in other languages, use JSON.
    #
    #               Note that Nanite uses JSON gem,
    #               and ActiveSupport's JSON encoder may cause clashes
    #               if ActiveSupport is loaded after JSON gem.
    #
    # root        : application root for this agent, defaults to Dir.pwd
    #
    # log_dir     : path to directory where agent stores it's log file
    #               if not given, app_root is used.
    #
    # file_root   : path to directory to files this agent provides
    #               defaults to app_root/files
    #
    # ping_time   : time interval in seconds between two subsequent heartbeat messages
    #               this agent broadcasts. Default value is 15.
    #
    # threaded_actors : when true, each message agent handles is handled in a separate thread
    #
    # console     : true tells Nanite to start interactive console
    #
    # daemonize   : true tells Nanite to daemonize
    #
    # services    : list of services provided by this agent, by default
    #               all methods exposed by actors are listed
    #
    # Connection options:
    #
    # vhost    : AMQP broker vhost that should be used
    #
    # user     : AMQP broker user
    #
    # pass     : AMQP broker password
    #
    # host     : host AMQP broker (or node of interest) runs on,
    #            defaults to 0.0.0.0
    #
    # port     : port AMQP broker (or node of interest) runs on,
    #            this defaults to 5672, port used by some widely
    #            used AMQP brokers (RabbitMQ and ZeroMQ)
    #
    #
    # On start Nanite reads config.yml, so it is common to specify
    # options in the YAML file. However, when both Ruby code options
    # and YAML file specify option, Ruby code options take precedence.
    def self.start(options={})
      new(options)
    end

    DEFAULT_OPTIONS = {:identity => Identity.generate, :root => Dir.pwd, :log_level => :info, :host => '0.0.0.0', :ping_time => 15,
      :default_services => [], :daemonize => false, :secure => false, :console => false, :format => :marshal} unless const_defined?('DEFAULT_OPTIONS')

    def initialize(opts)
      @options = DEFAULT_OPTIONS.merge(opts)
      @options[:file_root] = File.join(@options[:root], 'files')
      @options.update(custom_config)
      @identity = "nanite-#{options[:identity]}"
      @log = Log.new(@options, @identity)
      @serializer = Serializer.new(@options[:format])
      @status_proc = lambda { parse_uptime(`uptime`) rescue 'no status' }
      daemonize if @options[:daemonize]
      @amq = start_amqp(@options)
      @actors = {}
      load_actors
      setup_queue
      advertise_services
      setup_heartbeat
      start_console if @options[:console] && !@options[:daemonize]
    end

    def register(actor_instance, prefix = nil)
      raise ArgumentError, "#{actor_instance.inspect} is not a Nanite::Actor subclass instance" unless Nanite::Actor === actor_instance
      log.info("Registering #{actor_instance.inspect} with prefix #{prefix.inspect}")
      prefix ||= actor_instance.class.default_prefix
      actors[prefix.to_s] = actor_instance
    end

    protected

    def dispatch(request)
      _, prefix, meth = request.type.split('/')
      begin
        actor = actors[prefix]
        res = actor.send((meth.nil? ? "index" : meth), request.payload)
      rescue Exception => e
        res = "#{e.class.name}: #{e.message}\n  #{e.backtrace.join("\n  ")}"
      end
      Result.new(request.token, request.reply_to, res, identity) if request.reply_to
    end

    def receive(packet)
      packet = serializer.load(packet)
      case packet
      when Advertise
        log.debug("handling Advertise: #{packet}")
        advertise_services
      when Request
        log.debug("handling Request: #{packet}")
        result = dispatch(packet)
        amq.queue(packet.reply_to, :no_declare => true).publish(serializer.dump(result)) if packet.reply_to
      end
    end

    def services
      actors.map {|prefix, actor| actor.class.provides_for(prefix) }.flatten.uniq
    end

    def custom_config
      if options[:root]
        file = File.expand_path(File.join(options[:root], 'config.yml'))
        return YAML.load(IO.read(file)) if File.exists?(file)
      end
      {}
    end

    def setup_queue
      amq.queue(identity, :exclusive => true).subscribe do |msg|
        if options[:threaded_actors]
          Thread.new(msg) do |msg_in_thread|
            receive(msg_in_thread)
          end
        else
          receive(msg)
        end
      end
    end

    def setup_heartbeat
      EM.add_periodic_timer(options[:ping_time]) do
        amq.fanout('heartbeat', :no_declare => secure?).publish(serializer.dump(Ping.new(identity, status_proc.call)))
      end
    end

    def advertise_services
      log.debug("advertise_services: #{services.inspect}")
      amq.fanout('registration', :no_declare => secure?).publish(serializer.dump(Register.new(identity, services, status_proc.call)))
    end

    def load_actors
      return unless options[:root]

      Dir["#{options[:root]}/actors/*.rb"].each do |actor|
        log.info("loading actor: #{actor}")
        require actor
      end

      if File.exist?(options[:root] / 'init.rb')
        instance_eval(File.read(options[:root] / 'init.rb'), options[:root] / 'init.rb')
      end
    end

    def parse_uptime(up)
      if up =~ /load averages?: (.*)/
        a,b,c = $1.split(/\s+|,\s+/)
        (a.to_f + b.to_f + c.to_f) / 3
      end
    end

    def secure?
      options[:secure]
    end
  end
end
