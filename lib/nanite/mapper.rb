require 'nanite/reducer'
require 'nanite/dispatcher'
require 'nanite/persistence'
#AMQP.logging = true

module Nanite
  class Runner
    def start(opts={})
      EM.run{
        AMQP.start opts
        MQ.new.rpc('mapper', Mapper.new)
      }
    end
  end  
  
  class Mapper
    
    def log *args
      p args
    end
    
    def initialize
      @db = Nanite::MapperStore.new
      @nanites = @db.load_agents
      log "loaded agents from store", @nanites.keys
      @amq = MQ.new
      @amq.queue("mapper.pings",:exclusive => true).subscribe{ |msg|
        handle_pong(Marshal.load(msg))
      }
      @amq.queue("mapper.master",:exclusive => true).subscribe{ |msg|
        handle_pong(Marshal.load(msg))
      }
      @pings = {}
      send_pings
      EM.add_periodic_timer(30) { send_pings }
    end
    
    def handle_pong(pong)
      if pongs = @pings[pong.token]
        pongs.reject! {|p| p == pong.from }
      end  
    end
    
    def send_pings
      log "send_pings"
      tok = Nanite.gen_token
      @pings[tok] = []
      @nanites.keys.each do |agent|
        ping = Nanite::Ping.new(tok, agent, "mapper.pings")
        @pings[ping.token] << ping.to
        @amq.queue(agent).publish(Marshal.dump(ping))
      end
      EM.add_timer(3) do
        if @pings[tok].size == 0
          log "got all pongs" 
        else
          log "missing pongs for:", @pings[tok]
          @pings[tok].each do |a|
            @nanites.delete(a)
            @db.delete_agent(a)
            log "removed #{a} from mapping/discovery"
          end  
        end
        @pings.delete(tok)  
      end  
    end
    
    def register(name, resources)
      log "registering:", name, resources
      @nanites[name] = resources
      @db.add_agent(name, resources)
      "registered"
    end
    
    def add_resources(name, resources)
      log "adding resources:", name, resources
      resources.each do |res|
        (@nanites[name] ||= []) << Nanite::Resource.new(res)
      end
      @db.update_agent(name, @nanites[name])
    end
    
    def remove_resource(name, resource)
      log "removing resources:", name, resource
      resource = Nanite::Resource.new(resource)
      @nanites[name].reject! do |res|
        res == resource
      end  
    end
    
    def discover(resources)
      log "discover:", resources
      names = []
      @nanites.each do |name, provided|      
        names << name if Nanite::Dispatcher.can_provide?(resources, provided)
      end  
      names
    end
    
    def route(op)
      log "route:", op
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