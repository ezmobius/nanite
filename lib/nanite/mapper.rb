require 'nanite/reducer'
require 'nanite/dispatcher'
require 'nanite/persistence'
#AMQP.logging = true

module Nanite
  class Runner
    def start(opts={})
      EM.run{
        db = opts.delete(:db)
        AMQP.start opts
        MQ.new.rpc('mapper', Mapper.new(db))    
      }  
    end
  end  
  
  class Mapper
    
    def log *args
      p args
    end
    
    def initialize(db)
      @db = Nanite::MapperStore.new(db)
      @nanites = @db.load_agents
      log "loaded agents from store", @nanites.keys
      @amq = MQ.new
      @pings = {}
      setup_as_slave
      EM.add_periodic_timer(10) { log "current nanites(#{@nanites.keys.size}):", @nanites.keys }
      EM.next_tick { check_master }
      EM.add_periodic_timer(30) { send_pings if @role == :master }
    end
    
    def promote_to_master
      @role = :master
      EM.next_tick do
        setup_as_master
        send_pings
      end
      @amq.queue("mapper.slave").delete
      log "removed mapper.slave queue"
    end
    
    def setup_as_slave
      @role = :slave
      @master_pings = []
      @amq.queue("mapper.slave",:exclusive => true).subscribe{ |msg|
        handle_slave_packet(Marshal.load(msg))
      }
      EM.add_periodic_timer(6) { check_master if @role == :slave }
      EM.add_timer(4) { request_nanites }
      log "running as slave"
    end
    
    def setup_as_master
      @role = :master
      @amq.queue("mapper.master",:exclusive => true).subscribe{ |msg|
        handle_master_packet(Marshal.load(msg))
      }
      @amq.queue("mapper.master.pings",:exclusive => true).subscribe{ |msg|
        handle_master_packet(Marshal.load(msg))
      }
      log "running as master"
    end
    
    def check_master      
      tok = Nanite.gen_token
      ping = Nanite::Ping.new(tok, 'mapper.master', "mapper.slave")
      @master_pings << ping
      @amq.queue('mapper.master').publish(Marshal.dump(ping))
      EM.add_timer(3) do
        if @master_pings.size == 0
          log "got pong from master... remaing as slave" 
        else
          log "no pong from master, promoting myself to master"
          promote_to_master
        end
      end  
    end
    
    def request_nanites
      log "requesting nanites"
      @amq.queue('mapper.master').publish(Marshal.dump(Nanite::MapperStateRequest.new))
    end
    
    def handle_slave_packet(msg)
      case msg
      when Nanite::Pong
        @master_pings.reject! {|p| p.token == msg.token}
      when DeleteOneNanite
        @nanites.delete(msg.nanite)
        @db.delete_agent(msg.nanite)
      when AddOneNanite
        @nanites[msg.nanite] = msg.resources
        @db.add_agent(msg.nanite, msg.resources)
      when Nanite::MapperState
        log "got nanites form master", msg.nanites.keys
        merge_nanites(msg)
      when Nanite::MapperStateRequest
        @amq.queue('mapper.master').publish(Marshal.dump(Nanite::MapperState.new(@nanites)))
        
      end
    end
    
    def merge_nanites(msg)
      @nanites.merge!(msg.nanites)
      @nanites.each do |nanite|
        unless msg.nanites[nanite]
          @nanites.delete(nanite) 
          @db.delete_agent(nanite)
          next
        end
        @db.update_agent(nanite, @nanites[nanite])
      end  
    end
    
    def handle_master_packet(msg)
      case msg
      when Nanite::Pong
        handle_pong(msg)
      when Nanite::Ping
        handle_ping(msg)
      when DeleteOneNanite
        @nanites.delete(msg.nanite)
        @db.delete_agent(msg.nanite)
      when AddOneNanite
        @nanites[msg.nanite] = msg.resources
        @db.add_agent(msg.nanite, msg.resources)  
      when Nanite::MapperState
        log "got nanites from slave", msg.nanites.keys
        merge_nanites(msg)
      when Nanite::MapperStateRequest
        @amq.queue('mapper.slave').publish(Marshal.dump(Nanite::MapperState.new(@nanites)))
      end
    end
    
    def handle_ping(ping)
      if ping.from == 'mapper.slave'
        Nanite.amq.queue(ping.from).publish(Marshal.dump(Nanite::Pong.new(ping)))
      end  
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
        ping = Nanite::Ping.new(tok, agent, "mapper.master.pings")
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
            @amq.queue('mapper.slave').publish(Marshal.dump(Nanite::DeleteOneNanite.new(a)))
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
      queue = @role == :master ? 'mapper.slave' : 'mapper.master'
      @amq.queue(queue).publish(Marshal.dump(Nanite::AddOneNanite.new(name, resources)))
      "registered"
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