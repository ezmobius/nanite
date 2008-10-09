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
  
  class Runner
    
    def self.start(opts={})
      EM.run{
        ping_time = opts.delete(:ping_time) || 15
        AMQP.start opts
        Nanite.mapper = Mapper.new(ping_time)
        Nanite.start_console #if opts[:start_console]
      }  
    end
  end  
  
  class Mapper
    attr_accessor :nanites
    def log *args
      p args
    end
    
    def initialize(ping_time)
      @identity = Nanite.gen_token
      @ping_time = ping_time
      @nanites = {}
      @amq = MQ.new
      setup_queues
      log "starting mapper with nanites(#{@nanites.keys.size}):", @nanites.keys
      EM.add_periodic_timer(@ping_time) { check_pings }
    end
    
    def setup_queues
      log "setting up queues"
      @amq.queue("pings#{@identity}",:exclusive => true).bind(@amq.topic('heartbeat'), :key => 'nanite.pings').subscribe{ |ping|
        handle_ping(Marshal.load(ping))
      }
      @amq.queue("mapper#{@identity}",:exclusive => true).bind(@amq.topic('registration'), :key => 'nanite.register').subscribe{ |msg|
        register(Marshal.load(msg))
      }
      @amq.queue(Nanite.identity, :exclusive => true).subscribe{ |msg|
        msg = Marshal.load(msg)
        p msg
        Nanite.reducer.handle_result(msg)
      }
    end        
    
    def handle_ping(ping)
      if nanite = @nanites[ping.from]
        nanite[:timestamp] = Time.now
        nanite[:status] = ping.status
        @amq.queue(ping.identity).publish(Marshal.dump(Nanite::Pong.new(ping)))
      else
        @amq.queue(ping.identity).publish(Marshal.dump(Nanite::Advertise.new(ping)))
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
      log "least_loaded: #{res}"
      candidates = select_nanites { |n,r| r[:services].include?(res) }
      [candidates.min { |a,b|  a[1][:status] <=> b[1][:status] }]
    end
    
    def all(res)
      log "all: #{res}"
      select_nanites { |n,r| r[:services].include?(res) }
    end
    
    def random(res)
      log "random: #{res}"
      candidates = select_nanites { |n,r| r[:services].include?(res) }
      [candidates[rand(candidates.size-1)]]
    end
    
    def request(type, payload="", selector = :least_loaded, &blk)
      req = Nanite::Request.new(type, payload)
      req.token = Nanite.gen_token
      req.reply_to = Nanite.identity
      answer = route(req, selector)
      p "answer: #{answer.inspect}"
      if answer
        Nanite.callbacks[answer.token] = blk if blk
        Nanite.reducer.watch_for(answer)
        answer.token
      else
        puts "failed"
      end    
    end
    
    def route(req, selector)
      log "route(req) from:#{req.from}, #{selector}" 
      targets = __send__(selector, req.type)
       p targets
      unless  targets.empty?
        answer = Answer.new(req.token)
        
        workers = targets.map{|t| t.first }
        p workers
        
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
    
    def file(getfile)
      log "file(getfile) from:#{getfile.from}" 
      target = discover(getfile.services).first
      token = Nanite.gen_token
      file_transfer = FileTransfer.new(token)
      getfile.token = token
      
      if allowed?(getfile.from, target.first)       
        file_transfer.worker = target.first
        EM.next_tick {
          send_op(getfile, target.last)
        }
        file_transfer
      else
      end    
    end
    
    def send_request(req, target)
      log "send_op:", req, target
      @amq.queue(target).publish(Marshal.dump(req))
    end
        
  end  
end