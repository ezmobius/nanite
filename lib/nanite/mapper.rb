require 'nanite/reducer'
require 'nanite/dispatcher'
#AMQP.logging = true

module Nanite
  class Runner
    def start
      EM.run{
        MQ.new.rpc('mapper', Mapper.new(Reducer.new))
      }
    end
  end
  
  class Mapper
    
    def log *args
      p args
    end
    
    def initialize(reducer)
      @reducer = reducer
      @nanites = {}
      @amq = MQ.new
    end
    
    def register(name, resources)
      log "registering:", name, resources
      @nanites[name] = resources
      "registered"
    end
    
    def add_resources(name, resources)
      log "adding resources:", name, resources
      resources.each do |res|
        (@nanites[name] ||= []) << Nanite::Resource.new(res)
      end
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
      

      @reducer.watch_for(answer)
      EM.next_tick {
        targets.each do |target|
          send_op(op, target) if allowed?(op.from, target)
        end
      }
      
      if targets.empty?
        "Resources Not Found"
      else  
        token
      end
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