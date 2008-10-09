require 'rubygems'
require 'amqp'
require 'mq'
$:.unshift File.dirname(__FILE__)
require 'nanite/packets'
require 'nanite/reducer'
require 'nanite/dispatcher'
require 'nanite/actor'
require 'nanite/streaming'
require 'extlib'

module Nanite

  VERSION = '0.1' unless defined?(Nanite::VERSION)

  class << self
    attr_accessor :identity, :status_proc, :results, :root, :vhost, :file_root, :files, :host

    attr_accessor :default_services, :last_ping, :ping_time

    include FileStreaming

    def send_ping
      ping = Nanite::Ping.new(Nanite.identity, Nanite.status_proc.call)
      Nanite.amq.topic('heartbeat').publish(Marshal.dump(ping), :key => 'nanite.pings')
    end

    def advertise_services
      p "advertise_services",Nanite::Dispatcher.all_services
      reg = Nanite::Register.new(Nanite.identity, Nanite::Dispatcher.all_services, Nanite.status_proc.call)
      Nanite.amq.topic('registration').publish(Marshal.dump(reg), :key => 'nanite.register')
    end

    def start_console
      puts "starting console"
      require 'readline'
      Thread.new{
        while l = Readline.readline('>> ')
          unless l.nil? or l.strip.empty?
            Readline::HISTORY.push(l)
            begin
              p eval(l, ::TOPLEVEL_BINDING)
            rescue => e
              puts "#{e.class.name}: #{e.message}\n  #{e.backtrace.join("\n  ")}"
            end
          end
        end
      }
    end

    def load_actors
      Dir["#{Nanite.root}/actors/*.rb"].each do |actor|
        puts "loading actor: #{actor}"
        require actor
      end
    end

    def start(opts={})
      config = YAML::load(IO.read(File.expand_path(File.join(opts[:root], 'config.yml')))) rescue {}
      opts = config.merge(opts)
      Nanite.root              = opts[:root]
      Nanite.identity          = opts[:identity] || Nanite.gen_token
      Nanite.host              = opts[:host] || '0.0.0.0'
      Nanite.vhost             = opts[:vhost]
      Nanite.file_root         = opts[:file_root] || Dir.pwd
      Nanite.default_services  = opts[:services] || []

      AMQP.start :user  => opts[:user],
                 :pass  => opts[:pass],
                 :vhost => Nanite.vhost,
                 :host  => Nanite.host,
                 :port  => (opts[:port] || ::AMQP::PORT).to_i

      load_actors
      advertise_services

      EM.add_periodic_timer(15) do
        send_ping
      end

      Nanite.amq.queue(Nanite.identity, :exclusive => true).subscribe{ |msg|
        Nanite::Dispatcher.handle(Marshal.load(msg))
      }
      start_console if opts[:console]
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

    def gen_token
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
  end
end
