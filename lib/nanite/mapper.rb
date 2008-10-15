require 'nanite'
require 'nanite/reducer'
require 'nanite/dispatcher'

module Nanite
  class << self
    
    attr_accessor :mapper    
    
    def request(type, payload="", selector = :least_loaded, &blk)
      Nanite.mapper.request(type, payload, selector,  &blk)
    end
  end
  
  class Mapper
    def self.start(opts={})
      EM.run{
        ping_time = opts.delete(:ping_time) || 15
        start_console = opts.delete(:console)
        AMQP.start opts
        Nanite.mapper = Mapper.new(ping_time)
        Nanite.start_console if start_console
      }  
    end
    
    attr_accessor :nanites, :timeouts
    def log *args
      p args
    end
    
    def initialize(ping_time)
      @identity = Nanite.gensym
      @ping_time = ping_time
      @nanites = {}
      @amq = MQ.new
      @timeouts = {}
      setup_queues
      log "starting mapper with nanites(#{@nanites.keys.size}):", @nanites.keys
      EM.add_periodic_timer(@ping_time) do 
        check_pings 
        EM.next_tick { check_timeouts }
      end
    end
    
    def setup_queues
      log "setting up queues"
      @amq.queue("pings#{@identity}",:exclusive => true).bind(@amq.topic('heartbeat'), :key => 'nanite.pings').subscribe{ |ping|
        handle_ping(Nanite.load_packet(ping))
      }
      @amq.queue("mapper#{@identity}",:exclusive => true).bind(@amq.topic('registration'), :key => 'nanite.register').subscribe{ |msg|
        register(Nanite.load_packet(msg))
      }
      @amq.queue(Nanite.identity, :exclusive => true).subscribe{ |msg|
        msg = Nanite.load_packet(msg)
        Nanite.reducer.handle_result(msg)
      }
    end        
    
    def handle_ping(ping)
      if nanite = @nanites[ping.from]
        nanite[:timestamp] = Time.now
        nanite[:status] = ping.status
        @amq.queue(ping.identity).publish(Nanite.dump_packet(Nanite::Pong.new))
      else
        @amq.queue(ping.identity).publish(Nanite.dump_packet(Nanite::Advertise.new))
      end  
    end
    
    def check_pings
      time = Time.now
      @nanites.each do |name, content|
        if (time - content[:timestamp]) > @ping_time
          @nanites.delete(name)
          log "removed #{name} from mapping/registration"
        end
      end  
    end
    
    def register(reg)
      @nanites[reg.identity] = {:timestamp => Time.now,
                                :services => reg.services,
                                :status    => reg.status}
      log "registered:", reg.identity, reg.services
    end

    def select_nanites
      names = []
      @nanites.each do |name, content|
        names << [name, content] if yield(name, content)
      end
      names
    end
    
    def least_loaded(res)
      candidates = select_nanites { |n,r| r[:services].include?(res) }
      [candidates.min { |a,b|  a[1][:status] <=> b[1][:status] }]
      #sorted = candidates.sort { |a,b|  a[1][:status] <=> b[1][:status] }
      #case sorted.size
    end
    
    def all(res)
      select_nanites { |n,r| r[:services].include?(res) }
    end
    
    def random(res)
      candidates = select_nanites { |n,r| r[:services].include?(res) }
      [candidates[rand(candidates.size)]]
    end
    
    def request(type, payload="", opts = {:selector => :least_loaded, :timeout => 60}, &blk)
      req = Nanite::Request.new(type, payload)
      req.token = Nanite.gensym
      req.reply_to = Nanite.identity
      if answer = route(req, opts[:selector])
        Nanite.callbacks[answer.token] = blk if blk
        Nanite.reducer.watch_for(answer)
        @timeouts[answer.token] = (Time.now + opts[:timeout])
        answer.token
      else
        puts "failed"
      end    
    end
    
    def check_timeouts
      puts "checking timeouts"
      time = Time.now
      @timeouts.each do |tok, timeout|
        if time > timeout
          timeout = @timeouts.delete(tok) 
          p "request timeout: #{tok}"
          callback = Nanite.callbacks.delete(tok)
          callback.call(nil) if callback
        end  
      end  
    end
    
    def route(req, selector)
      targets = __send__(selector, req.type)
      unless  targets.empty?
        answer = Answer.new(req.token)
        
        workers = targets.map{|t| t.first }
        
        answer.workers = Hash[*workers.zip(Array.new(workers.size, :waiting)).flatten]
            
        EM.next_tick {
          workers.each do |worker|
            send_request(req, worker)
          end
        }
        answer
      else
        nil
      end    
    end
    
    def send_request(req, target)
      @amq.queue(target).publish(Nanite.dump_packet(req))
    end
        
  end  
end