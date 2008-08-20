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
        MQ.new.rpc('mapper', Mapper.new(db, ping_time, heartbeat_time))    
      }  
    end
  end  
  
  class Mapper
    
    def log *args
      p args
    end
    
    def initialize(db, ping_time, heartbeat_time)
      @ping_time = ping_time
      @heartbeat_time = heartbeat_time
      @db = Nanite::MapperStore.new(db)
      @nanites = @db.load_agents
      log "loaded agents from store", @nanites.keys
      @amq = MQ.new
      @pings = {}
      setup_as_slave
      EM.add_periodic_timer(30) { log "current nanites(#{@nanites.keys.size}):", @nanites.keys }
      EM.add_periodic_timer(@ping_time) { send_pings if @role == :master }
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
      EM.add_periodic_timer(@heartbeat_time) { check_master if @role == :slave }
      check_master
      request_mapper_state
      log "running as slave"
    end
    
    def setup_as_master
      @role = :master
      @amq.queue("mapper.master",:exclusive => true).subscribe{ |msg|
        handle_master_packet(Marshal.load(msg))
      }
      @amq.queue("mapper.master.heartbeat",:exclusive => true).subscribe{ |msg|
        handle_master_packet(Marshal.load(msg))
      }
      log "running as master"
    end
    
    def check_master      
      tok = Nanite.gen_token
      ping = Nanite::Ping.new(tok, 'mapper.master.heartbeat', "mapper.slave")
      @master_pings << ping
      @amq.queue('mapper.master.heartbeat').publish(Marshal.dump(ping))
      EM.add_timer(@heartbeat_time * 0.66) do
        unless @master_pings.size == 0
          log "no pong from master, promoting myself to master"
          promote_to_master
        end
      end  
    end
    
    def request_mapper_state
      log "request_mapper_state"
      @amq.queue('mapper.master.heartbeat').publish(Marshal.dump(Nanite::MapperStateRequest.new))
    end
    
    def handle_slave_packet(msg)
      case msg
      when Nanite::Pong
        @master_pings.reject! {|p| p.token == msg.token}
      when DeleteOneNanite
        @nanites.delete(msg.nanite)
        @db.delete_agent(msg.nanite)
        log "removed #{msg.nanite} from mapping/discovery"
      when AddOneNanite
        @nanites[msg.nanite] = msg.resources
        @db.register_agent(msg.nanite, msg.resources)
      when Nanite::MapperState
        log "got nanites from master", msg.nanites.keys
        merge_nanites!(msg)
      when Nanite::MapperStateRequest
        @amq.queue('mapper.master.heartbeat').publish(Marshal.dump(Nanite::MapperState.new(@nanites)))
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
        @db.register_agent(msg.nanite, msg.resources)  
      when Nanite::MapperState
        log "got nanites from slave", msg.nanites.keys
        merge_nanites!(msg)
      when Nanite::MapperStateRequest
        @amq.queue('mapper.slave').publish(Marshal.dump(Nanite::MapperState.new(@nanites)))
      end
    end
    
    def merge_nanites!(msg)
      @nanites.merge!(msg.nanites)
      @nanites.each do |nanite|
        unless msg.nanites[nanite]
          @nanites.delete(nanite) 
          @db.delete_agent(nanite)
          next
        end
        @db.register_agent(nanite, @nanites[nanite])
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
        ping = Nanite::Ping.new(tok, agent, "mapper.master")
        @pings[ping.token] << ping.to
        @amq.queue(agent).publish(Marshal.dump(ping))
      end
      EM.add_timer(@ping_time * 0.66) do
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
      @db.register_agent(name, resources)
      queue = @role == :master ? 'mapper.slave' : 'mapper.master.heartbeat'
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
      @amq.queue(target).publish(Marshal.dump(op), :from => 'mapper')
    end
        
    def allowed?(from, to)
      true
    end    
        
  end  
end