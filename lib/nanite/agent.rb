module Nanite
  class Agent
    include AMQPHelper
    include FileStreaming
    include ConsoleHelper
    include DaemonizeHelper

    attr_reader :identity, :log, :options, :serializer, :dispatcher, :registry, :amq
    attr_accessor :status_proc

    DEFAULT_OPTIONS = COMMON_DEFAULT_OPTIONS.merge({:user => 'agent', :identity => nil, :ping_time => 15,
      :default_services => []}) unless defined?(DEFAULT_OPTIONS)

    # Initializes a new agent and establishes AMQP connection.
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
    # On start Nanite reads config.yml, so it is common to specify
    # options in the YAML file. However, when both Ruby code options
    # and YAML file specify option, Ruby code options take precedence.
    def self.start(options = {})
      new(options)
    end

    def initialize(opts)
      @options = DEFAULT_OPTIONS.merge(opts)
      @options[:file_root] = File.join(@options[:root], 'files')
      @options.update(custom_config)
      set_identity
      @log = Log.new(@options, @identity)
      @serializer = Serializer.new(@options[:format])
      @status_proc = lambda { parse_uptime(`uptime`) rescue 'no status' }
      daemonize if @options[:daemonize]
      @amq = start_amqp(@options)
      @registry = ActorRegistry.new(@log)
      @dispatcher = Dispatcher.new(@amq, @registry, @serializer, @identity, @log, @options)
      load_actors
      setup_queue
      advertise_services
      setup_heartbeat
      start_console if @options[:console] && !@options[:daemonize]
    end

    def register(actor, prefix = nil)
      registry.register(actor, prefix)
    end

    protected

    def set_identity
      return @identity = "nanite-#{options[:identity]}" if options[:identity]
      token = Identity.generate
      @identity = "nanite-#{token}"
      orig_custom_config = custom_config.clone
      File.open(File.expand_path(File.join(options[:root], 'config.yml')), 'w') do |fd|
        fd.write(YAML.dump(orig_custom_config.merge(:identity => token)))
      end
    end

    def load_actors
      return unless options[:root]
      Dir["#{options[:root]}/actors/*.rb"].each do |actor|
        log.info("loading actor: #{actor}")
        require actor
      end
      init_path = File.join(options[:root], 'init.rb')
      instance_eval(File.read(init_path), init_path) if File.exist?(init_path)
    end

    def receive(packet)
      packet = serializer.load(packet)
      case packet
      when Advertise
        log.debug("handling Advertise: #{packet}")
        advertise_services
      when Request
        log.debug("handling Request: #{packet}")
        dispatcher.dispatch(packet)
      end
    end

    def custom_config
      if options[:root]
        file = File.expand_path(File.join(options[:root], 'config.yml'))
        return YAML.load(IO.read(file)) || {} if File.exists?(file)
      end
      {}
    end

    def setup_queue
      amq.queue(identity, :durable => true).subscribe(:ack => true) do |info, msg|
        info.ack
        receive(msg)
      end
    end

    def setup_heartbeat
      EM.add_periodic_timer(options[:ping_time]) do
        amq.fanout('heartbeat', :no_declare => options[:secure]).publish(serializer.dump(Ping.new(identity, status_proc.call)))
      end
    end

    def advertise_services
      log.debug("advertise_services: #{registry.services.inspect}")
      amq.fanout('registration', :no_declare => options[:secure]).publish(serializer.dump(Register.new(identity, registry.services, status_proc.call)))
    end

    def parse_uptime(up)
      if up =~ /load averages?: (.*)/
        a,b,c = $1.split(/\s+|,\s+/)
        (a.to_f + b.to_f + c.to_f) / 3
      end
    end
  end
end
