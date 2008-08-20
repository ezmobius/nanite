require 'nanite/reducer'
require 'nanite/dispatcher'
require 'nanite/persistence'
#AMQP.logging = true

module Nanite
  class Runner
    def start(opts={})
      EM.run{
        db = opts.delete(:db)
        ping_time = opts.delete(:ping_time) || 30
        heartbeat_time = opts.delete(:heartbeat_time) || 20
        AMQP.start opts
        MQ.new.rpc('mapper', Mapper.new(db, ping_time))  
      }  
    end
  end  
  
  class Mapper
    
    def log *args
      p args
    end
    
    def initialize(db, ping_time)
      @identity = Nanite.gen_token
      @ping_time = ping_time
      @db = Nanite::MapperStore.new(db)
      @nanites = @db.load_agents
      log "loaded agents from store", @nanites.keys
      @amq = MQ.new
      setup_queues
      EM.add_periodic_timer(30) { log "current nanites(#{@nanites.keys.size}):", @nanites.keys }
      EM.add_periodic_timer(@ping_time) { check_pings }
    end
    
    def setup_queues
      @amq.queue("pings#{@identity}",:exclusive => true).bind(@amq.topic('heartbeat'), :key => 'nanite.pings').subscribe{ |ping|
        handle_ping(Marshal.load(ping))
      }
      @amq.queue("mapper#{@identity}",:exclusive => true).bind(@amq.topic('registration'), :key => 'nanite.register').subscribe{ |msg|
        log "registration", msg = Marshal.load(msg)
        register(msg)
      }
    end        
    
    def handle_ping(ping)
      if nanite = @nanites[ping.from]
        nanite[:timestamp] = Time.now
        @amq.queue(ping.from).publish(Marshal.dump(Nanite::Pong.new(ping)))
      end  
    end
    
    def check_pings
      time = Time.now
      @nanites.each do |name, content|
        if (time - content[:timestamp]) > @ping_time
          @nanites.delete(name)
          @db.delete_agent(name)
          log "removed #{name} from mapping/registration"
        end
      end  
    end
    
    def register(reg)
      @nanites[reg.name] = {:timestamp => Time.now, :resources => reg.resources}
      @db.register_agent(reg.name, reg.resources)
      log "registered:", reg.name, reg.resources
    end
        
    def discover(resources)
      log "discover:", resources
      names = []
      @nanites.each do |name, content|      
        names << name if Nanite::Dispatcher.can_provide?(resources, content[:resources])
      end  
      names
    end
    
    def route(op)
      log "route(op) from:#{op.from}" 
      targets = discover(op.resources)
      token = Nanite.gen_token
      answer = Answer.new(token,op.from)
      op.token = token
      
      answer.workers = Hash[*targets.zip(Array.new(targets.size, :waiting)).flatten]
    
      EM.next_tick {
        targets.each do |target|
          send_op(op, target) if allowed?(op.from, target)
        end
      }
      answer
    end
    
    def send_op(op, target)
      log "send_op:", op, target
      @amq.queue(target).publish(Marshal.dump(op))
    end
        
    def allowed?(from, to)
      true
    end    
        
  end  
end