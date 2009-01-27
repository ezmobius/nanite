require 'yaml'

module Nanite
  class Agent
    attr_reader :identity, :format, :status_proc, :results, :root, :log_dir, :vhost, :file_root, :files, :host
    attr_reader :default_services, :last_ping, :ping_time

    attr_reader :opts

    include FileStreaming


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
    def load_actors
      return unless root

      Dir["#{root}/actors/*.rb"].each do |actor|
        log.info "loading actor: #{actor}"
        require actor
      end

      if File.exist?(root / 'init.rb')
        instance_eval(File.read(root / 'init.rb'), root / 'init.rb')
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
    # +Nanite.start+ documentation.
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

    def register(actor_instance, prefix = nil)
      dispatcher.register(actor_instance, prefix)
    end

    # Updates last ping time
    def pinged!
      @last_ping = Time.now
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
    # Default proc shells out to uptime and parses the output
    # to get load average values.
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

    # Request callbacks. Keys in this hash are
    # request tokens, and values are timestamps
    # so mapper can check up if request has timed
    # out and should be removed.
    def callbacks
      @callbacks ||= {}
    end

    # Request results. Keys in this hash are
    # request tokens.
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
