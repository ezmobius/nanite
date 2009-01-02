require 'rubygems'
require 'amqp'
require 'mq'
$:.unshift File.dirname(__FILE__)
require 'nanite/packets'
require 'nanite/reducer'
require 'nanite/dispatcher'
require 'nanite/actor'
require 'nanite/streaming'
require 'nanite/exchanges'
require 'nanite/marshal'
require 'nanite/console'
require 'extlib'
require 'json'
require 'logger'


module Nanite

  VERSION = '0.1.0' unless defined?(Nanite::VERSION)

  class << self
    attr_accessor :identity, :format, :status_proc, :results, :root, :vhost, :file_root, :files, :host

    attr_accessor :default_services, :last_ping, :ping_time

    attr_writer :log_level

    include FileStreaming

    def send_ping
      ping = Nanite::Ping.new(Nanite.identity, Nanite.status_proc.call)
      Nanite.amq.fanout('heartbeat').publish(Nanite.dump_packet(ping))
    end

    def advertise_services
      p "advertise_services",Nanite::Dispatcher.all_services
      reg = Nanite::Register.new(Nanite.identity, Nanite::Dispatcher.all_services, Nanite.status_proc.call)
      Nanite.amq.fanout('registration').publish(Nanite.dump_packet(reg))
    end

    def start_console
      puts "Starting IRB console under ::Nanite"
      Thread.new {
        Nanite::Console.start(Nanite)
      }
    end

    def load_actors
      begin
        require(Nanite.root / 'init')
      rescue LoadError
      end
      Dir["#{Nanite.root}/actors/*.rb"].each do |actor|
        Nanite.log.info "loading actor: #{actor}"
        require actor
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

    def start(opts={})
      config = YAML::load(IO.read(File.expand_path(File.join(opts[:root], 'config.yml')))) rescue {}
      opts = config.merge(opts)

      Nanite.log_level         = levels[opts[:log_level]]
      Nanite.root              = opts[:root]
      Nanite.format            = opts[:format] || :marshal
      Nanite.identity          = opts[:identity] || Nanite.gensym
      Nanite.host              = opts[:host] || '0.0.0.0'
      Nanite.vhost             = opts[:vhost]
      Nanite.file_root         = opts[:file_root] || "#{Nanite.root}/files"
      Nanite.default_services  = opts[:services] || []

      daemonize(opts[:log_file] || "#{Nanite.identity}.log") if opts[:daemonize]

      AMQP.start :user  => opts[:user],
                 :pass  => opts[:pass],
                 :vhost => Nanite.vhost,
                 :host  => Nanite.host,
                 :port  => (opts[:port] || ::AMQP::PORT).to_i

      load_actors
      advertise_services

      EM.add_periodic_timer((opts[:ping_time]||15).to_i) do
        send_ping
      end

      Nanite.amq.queue(Nanite.identity, :exclusive => true).subscribe{ |msg|
        if opts[:threaded_actors]
          Thread.new(msg) do |msg_in_thread|
            Nanite::Dispatcher.handle(Nanite.load_packet(msg_in_thread))
          end
        else
          Nanite::Dispatcher.handle(Nanite.load_packet(msg))
        end
      }
      start_console if opts[:console] && !opts[:daemonize]
    end

    def reducer
      @reducer ||= Nanite::Reducer.new
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
      Thread.current[:mq] ||= MQ.new
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
         log = Logger.new((Nanite.root||Dir.pwd) / "nanite.#{Nanite.identity}.log")
         log.level = Nanite.log_level
         log
      end
      @log
    end

    def gensym
      values = [
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x1000000),
        rand(0x1000000),
      ]
      "%04x%04x%04x%04x%04x%06x%06x" % values
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

