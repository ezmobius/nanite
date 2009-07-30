module Nanite
  class Agent
    include AMQPHelper
    include FileStreaming
    include ConsoleHelper
    include DaemonizeHelper

    attr_reader :identity, :options, :serializer, :dispatcher, :registry, :amq, :tags
    attr_accessor :status_proc

    DEFAULT_OPTIONS = COMMON_DEFAULT_OPTIONS.merge({:user => 'nanite', :ping_time => 15,
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
    # format      : format to use for packets serialization. One of the three:
    #               :marshall, :json, or :yaml. Defaults to
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
    # pid_dir     : path to the directory where the agent stores its pid file (only if daemonized)
    #               defaults to the root or the current working directory.
    #
    # services    : list of services provided by this agent, by default
    #               all methods exposed by actors are listed
    #
    # single_threaded: Run all operations in one thread
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
      agent = new(options)
      agent.run
      agent
    end

    def initialize(opts)
      set_configuration(opts)
      @tags = []
      @tags << opts[:tag]
      @tags.flatten!
      @options.freeze
    end
    
    def run
      log_path = false
      if @options[:daemonize]
        log_path = (@options[:log_dir] || @options[:root] || Dir.pwd)
      end
      Log.init(@identity, log_path)
      Log.level = @options[:log_level] if @options[:log_level]
      @serializer = Serializer.new(@options[:format])
      @status_proc = lambda { parse_uptime(`uptime`) rescue 'no status' }
      pid_file = PidFile.new(@identity, @options)
      pid_file.check
      if @options[:daemonize]
        daemonize
        pid_file.write
        at_exit { pid_file.remove }
      end
      @amq = start_amqp(@options)
      @registry = ActorRegistry.new
      @dispatcher = Dispatcher.new(@amq, @registry, @serializer, @identity, @options)
      setup_mapper_proxy
      load_actors
      setup_traps
      setup_queue
      advertise_services
      setup_heartbeat
      at_exit { un_register } unless $TESTING
      start_console if @options[:console] && !@options[:daemonize]
    end

    def register(actor, prefix = nil)
      registry.register(actor, prefix)
    end

    # Can be used in agent's initialization file to register a security module
    # This security module 'authorize' method will be called back whenever the
    # agent receives a request and will be given the corresponding deliverable.
    # It should return 'true' for the request to proceed.
    # Requests will return 'deny_token' or the string "Denied" by default when
    # 'authorize' does not return 'true'.
    def register_security(security, deny_token = "Denied")
      @security = security
      @deny_token = deny_token
    end

    protected

    def set_configuration(opts)
      @options = DEFAULT_OPTIONS.clone
      root = opts[:root] || @options[:root]
      custom_config = if root
        file = File.expand_path(File.join(root, 'config.yml'))
        File.exists?(file) ? (YAML.load(IO.read(file)) || {}) : {}
      else
        {}
      end
      opts.delete(:identity) unless opts[:identity]
      @options.update(custom_config.merge(opts))
      @options[:file_root] ||= File.join(@options[:root], 'files')
      return @identity = "nanite-#{@options[:identity]}" if @options[:identity]
      token = Identity.generate
      @identity = "nanite-#{token}"
      File.open(File.expand_path(File.join(@options[:root], 'config.yml')), 'w') do |fd|
        fd.write(YAML.dump(custom_config.merge(:identity => token)))
      end
    end

    def load_actors
      return unless options[:root]
      actors_dir = @options[:actors_dir] || "#{@options[:root]}/actors"
      actors = @options[:actors]
      Dir["#{actors_dir}/*.rb"].each do |actor|
        next if actors && !actors.include?(File.basename(actor, ".rb"))
        Nanite::Log.info("[setup] loading #{actor}")
        require actor
      end
      init_path = @options[:initrb] || File.join(options[:root], 'init.rb')
      instance_eval(File.read(init_path), init_path) if File.exist?(init_path)
    end

    def receive(packet)
      Nanite::Log.debug("RECV #{packet.to_s}")
      case packet
      when Advertise
        Nanite::Log.info("RECV #{packet.to_s}") unless Nanite::Log.level == Logger::DEBUG
        advertise_services
      when Request, Push
        if @security && !@security.authorize(packet)
          Nanite::Log.warn("RECV NOT AUTHORIZED #{packet.to_s}")
          if packet.kind_of?(Request)
            r = Result.new(packet.token, packet.reply_to, @deny_token, identity)
            amq.queue(packet.reply_to, :no_declare => options[:secure]).publish(serializer.dump(r))
          end
        else
          Nanite::Log.info("RECV #{packet.to_s([:from, :tags])}") unless Nanite::Log.level == Logger::DEBUG
          dispatcher.dispatch(packet)
        end
      when Result
        Nanite::Log.info("RECV #{packet.to_s([])}") unless Nanite::Log.level == Logger::DEBUG
        @mapper_proxy.handle_result(packet)
      when IntermediateMessage
        Nanite::Log.info("RECV #{packet.to_s([])}") unless Nanite::Log.level == Logger::DEBUG
        @mapper_proxy.handle_intermediate_result(packet)
      end
    end
    
    def tag(*tags)
      tags.each {|t| @tags << t}
      @tags.uniq!
    end

    def setup_queue
      amq.queue(identity, :durable => true).subscribe(:ack => true) do |info, msg|
        begin
          info.ack
          receive(serializer.load(msg))
        rescue Exception => e
          Nanite::Log.error("RECV #{e.message}")
        end
      end
    end

    def setup_heartbeat
      EM.add_periodic_timer(options[:ping_time]) do
        amq.fanout('heartbeat', :no_declare => options[:secure]).publish(serializer.dump(Ping.new(identity, status_proc.call)))
      end
    end
    
    def setup_mapper_proxy
      @mapper_proxy = MapperProxy.new(identity, options)
    end
    
    def setup_traps
      ['INT', 'TERM'].each do |sig|
        old = trap(sig) do
          un_register
          amq.instance_variable_get('@connection').close do
            EM.stop
            old.call if old.is_a? Proc
          end
        end
      end
    end
    
    def un_register
      unless @unregistered
        @unregistered = true
        Nanite::Log.info("SEND [un_register]")
        amq.fanout('registration', :no_declare => options[:secure]).publish(serializer.dump(UnRegister.new(identity)))
      end
    end

    def advertise_services
      reg = Register.new(identity, registry.services, status_proc.call, self.tags)
      Nanite::Log.info("SEND #{reg.to_s}")
      amq.fanout('registration', :no_declare => options[:secure]).publish(serializer.dump(reg))
    end

    def parse_uptime(up)
      if up =~ /load averages?: (.*)/
        a,b,c = $1.split(/\s+|,\s+/)
        (a.to_f + b.to_f + c.to_f) / 3
      end
    end
  end
end
