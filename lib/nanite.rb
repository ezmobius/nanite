require 'rubygems'
require 'amqp'
require 'mq'
$:.unshift File.dirname(__FILE__)
require 'nanite/resource'
require 'nanite/packets'
require 'nanite/reducer'
require 'nanite/dispatcher'
require 'nanite/actor'

module Nanite
  
  VERSION = '0.1' unless defined?(Nanite::VERSION)
  
  class << self
    attr_accessor :identity, :user, :pass, :root, :vhost
    
    attr_accessor :default_resources, :last_ping, :ping_time
    
    def root
      @root ||= File.expand_path(File.dirname(__FILE__))
    end
    
    def op(type, payload, *resources, &blk)
      token = Nanite.gen_token
      op = Nanite::Op.new(type, payload, *resources)
      op.reply_to = token
      Nanite.mapper.route(op) do |answer|
        Nanite.amq.queue(token, :exclusive => true).subscribe{ |msg|
          msg = Marshal.load(msg)
          Nanite.reducer.handle_result(msg)
        }
        Nanite.callbacks[token] = blk if blk
        Nanite.reducer.watch_for(answer)
        Nanite.pending[token] = answer.token
      end
      token
    end
    
    def send_ping
      ping = Nanite::Ping.new(Nanite.user, Nanite.identity)
      Nanite.amq.topic('heartbeat').publish(Marshal.dump(ping), :key => 'nanite.pings')
    end
    
    def advertise_resources
      puts "advertise_resources"
      reg = Nanite::Register.new(Nanite.user, Nanite.identity, Nanite::Dispatcher.all_resources)
      Nanite.amq.topic('registration').publish(Marshal.dump(reg), :key => 'nanite.register')
    end
    
    def start_console
      puts "starting console"
      require 'readline'
      Thread.new{
        while l = Readline.readline('>> ')
          unless l.nil? or l.strip.empty?
            Readline::HISTORY.push(l)
            eval l
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
      Nanite.user              = opts[:user]
      Nanite.pass              = opts[:pass]
      Nanite.vhost             = opts[:vhost]
      Nanite.default_resources = opts[:resources].map {|r| Nanite::Resource.new(r)}

      runner = proc do    
        AMQP.start :user  => Nanite.user,
                   :pass  => Nanite.pass,
                   :vhost => Nanite.vhost
        
        load_actors
        advertise_resources
                                
        EM.add_periodic_timer(30) do
          send_ping
        end
        
        Nanite.amq.queue(Nanite.identity, :exclusive => true).subscribe{ |msg|
          Nanite::Dispatcher.handle(Marshal.load(msg))
        }
        
        start_console if opts[:console]
        
      end
      if opts[:threaded]
        Thread.new { 
          until EM.reactor_running?
            sleep 0.01
          end
          runner.call 
        }
      else
        runner.call 
      end      
    end  
    
    def reducer
      @reducer ||= Nanite::Reducer.new
    end
    
    def mapper
      Thread.current[:mapper] ||= MQ.new.rpc('mapper')
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