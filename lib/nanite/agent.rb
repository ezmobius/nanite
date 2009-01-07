module Nanite
  class Agent
    attr_reader :identity, :format, :status_proc, :results, :root, :log_dir, :vhost, :file_root, :files, :host
    attr_reader :default_services, :last_ping, :ping_time

    attr_reader :opts

    include FileStreaming

    # Initializes a new agent and establishes
    # AMQP connection. To run agent as Mapper, pass :mapper => true.
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
    # log_file    : log file path, defaults to log_dir/nanite.[identity].log
    #
    # threaded_actors : when true, each message agent handles is handled in a separate thread
    #
    # console     : true tells Nanite to start interactive console
    #
    # daemonize   : true tells Nanite to daemonize
    # 
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
    #
    # Command line runner provided with Nanite out of the box parses
    # command line options and then uses this method, so it is safe to
    # consider it a single initialization point for every Nanite agent.
    # 
    # @api :public:
    def self.start(options = {})
      a = new(options)
      a.start
      a
    end

    # Sends a hearbeat message to the 'heartbeat' exchange of type
    # 'fanout'.
    def send_ping
      ping = Ping.new(identity, status_proc.call, identity)
      amq.fanout('heartbeat').publish(dump_packet(ping))
    end

    # Sends a services advertisement message to the 'registration' exchange of type
    # 'fanout'.
    def advertise_services
      log.debug "advertise_services: #{dispatcher.all_services.inspect}"
      reg = Register.new(identity, dispatcher.all_services, status_proc.call)
      amq.fanout('registration').publish(dump_packet(reg))
    end

    # Starts interactive Nanite shell.
    def start_console
      puts "Starting IRB console under ::Nanite"
      Thread.new {
        Console.start(self)
      }
    end

    # Loads Nanite actors that provide services.
    #
    # If app_root/init.rb is present, it is loaded and evaluated
    # in the scope of the agent.
    #
    # Nanite looks for actors under app_root/actors directory.
    # Actors are also evaluated in the scope of the agent
    # (using instance_eval).
    def load_actors
      return unless root
      if File.exist?(root / 'init.rb')
        instance_eval(File.read(root / 'init.rb'), root / 'init.rb')
      end

      Dir["#{root}/actors/*.rb"].each do |actor|
        log.info "loading actor: #{actor}"
        instance_eval(File.read(actor), actor)
      end
    end

    # Log level used, defaults to INFO.
    def log_level
      @log_level || Logger::INFO
    end

    # Log levels map, keys are:
    #
    # fatal (never log except on crashes)
    # error
    # warn
    # info
    # debug (most verbose)
    def levels
      @levels ||= {
          'fatal' => Logger::FATAL,
          'error' => Logger::ERROR,
          'warn'  => Logger::WARN,
          'info'  => Logger::INFO,
          'debug' => Logger::DEBUG
      }
    end

    # Initializes agent instance, for list of options see
    # +Nanite::Agent.start+ documentation.
    def initialize(options = {})
      config = {}
      if options[:root]
        config_filename = File.expand_path(File.join(options[:root], 'config.yml'))
        if File.exist?(config_filename)
          config = YAML::load(IO.read(config_filename))
        end
      end
      @opts = config.merge(options)

      @log_level         = levels[opts[:log_level]]
      @root              = opts[:root] || Dir.pwd
      @log               = opts[:log]
      @log_dir           = opts[:log_dir]
      @format            = opts[:format] || :marshal
      @identity          = opts[:identity] || Nanite.gensym
      @host              = opts[:host] || '0.0.0.0'
      @vhost             = opts[:vhost]
      @file_root         = opts[:file_root] || "#{root}/files"
      @ping_time         = (opts[:ping_time] || 15).to_i
      @default_services  = opts[:services] || []
    end

    # Does the following (in given order):
    #
    # 1. Establishes connection with AMQP broker.
    # 2. If :mapper option was given to the agent, agent starts in mapper mode.
    # 3. Loads actors.
    # 4. Advertises services.
    # 5. Sets up periodic timer for heartbeat notifications.
    # 6. If :console option is given, starts a console.
    # 7. If :daemonize option is given, agent daemonizes.
    # 
    # Mapper listens to exclusive queue (only one consumer allowed) that has
    # name of agent identity.
    #
    # See +Nanite::Agent.start+ documentation for more details.
    def start
      daemonize(opts[:log_file] || "#{identity}.log") if opts[:daemonize]

      AMQP.start :user  => opts[:user],
        :pass  => opts[:pass],
        :vhost => vhost,
        :host  => host,
        :port  => (opts[:port] || ::AMQP::PORT).to_i

      if opts[:mapper]
        log.debug "starting mapper"
        mapper.start
      else
        log.debug "starting nanite"
        load_actors
        advertise_services
  
        EM.add_periodic_timer(ping_time) do
          send_ping
        end
        
        amq.queue(identity, :exclusive => true).subscribe{ |msg|
          if opts[:threaded_actors]
            Thread.new(msg) do |msg_in_thread|
              dispatcher.handle(load_packet(msg_in_thread))
            end
          else
            dispatcher.handle(load_packet(msg))
          end
        }
      end
      
      start_console if opts[:console] && !opts[:daemonize]
    end

    # Updates last ping time
    def pinged!
      @last_ping = Time.now
    end

    # Registers actor instance with given prefix
    def register(prefix, actor_instance=nil)
      dispatcher.register(prefix, actor_instance)
    end

    # Returns dispatcher instance associated with this agent.
    # See Nanite::Dispatcher for details.
    def dispatcher
      @dispatcher ||= Dispatcher.new(self)
    end

    # Returns reducer instance associated with this agent.
    # See Nanite::Reducer for details.
    def reducer
      @reducer ||= Reducer.new(self)
    end

    # A callable object that calculates load of this agent.
    # Default proc shells out to uptime and parser the output
    # to get LA values.
    def status_proc
      @status_proc ||= lambda{ parse_uptime(`uptime`) rescue "no status"}
    end

    # Extracts load average values from a string returned
    # by uptime utility.
    def parse_uptime(up)
      if up =~ /load averages?: (.*)/
        a,b,c = $1.split(/\s+|,\s+/)
        (a.to_f + b.to_f + c.to_f) / 3
      end
    end

    # Message queue instance used by the agent.
    # For documentation, see AMQP::MQ in amqp gem rdoc.
    def amq
      @amq ||= MQ.new
    end

    def pending
      @pending ||= {}
    end

    def callbacks
      @callbacks ||= {}
    end

    def results
      @results ||= {}
    end

    # Returns a logger instance used by the agent.
    def log
      @log ||= begin
                 log = Logger.new((log_dir||root||Dir.pwd) / "nanite.#{identity}.log")
                 log.level = log_level
                 log
               end
      @log
    end

    protected
    def daemonize(log_file)
      exit if fork
      Process.setsid
      exit if fork
      $stdin.reopen("/dev/null")
      $stdout.reopen(log_file, "a")
      $stderr.reopen($stdout)
    end
  end
end
