module Nanite
  class Agent
    attr_reader :identity, :format, :status_proc, :results, :root, :log_dir, :vhost, :file_root, :files, :host
    attr_reader :default_services, :last_ping, :ping_time

    attr_reader :opts

    include FileStreaming

    def self.start(options = {})
      a = new(options)
      a.start
      a
    end

    def send_ping
      ping = Ping.new(identity, status_proc.call, identity)
      amq.fanout('heartbeat').publish(dump_packet(ping))
    end

    def advertise_services
      log.debug "advertise_services: #{dispatcher.all_services.inspect}"
      reg = Register.new(identity, dispatcher.all_services, status_proc.call)
      amq.fanout('registration').publish(dump_packet(reg))
    end

    def start_console
      puts "Starting IRB console under ::Nanite"
      Thread.new {
        Console.start(self)
      }
    end

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

    def log_level
      @log_level || Logger::INFO
    end

    def levels
      @levels ||= {
          'fatal' => Logger::FATAL,
          'error' => Logger::ERROR,
          'warn'  => Logger::WARN,
          'info'  => Logger::INFO,
          'debug' => Logger::DEBUG
      }
    end

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

    def pinged!
      @last_ping = Time.now
    end

    def register(prefix, actor_instance)
      dispatcher.register(prefix, actor_instance)
    end

    def dispatcher
      @dispatcher ||= Dispatcher.new(self)
    end

    def reducer
      @reducer ||= Reducer.new(self)
    end

    def status_proc
      @status_proc ||= lambda{ parse_uptime(`uptime`) rescue "no status"}
    end

    def parse_uptime(up)
      if up =~ /load averages?: (.*)/
        a,b,c = $1.split(/\s+|,\s+/)
        (a.to_f + b.to_f + c.to_f) / 3
      end
    end

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
