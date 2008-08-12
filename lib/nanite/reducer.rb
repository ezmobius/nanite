#AMQP.logging = true
module Nanite
      
  class Reducer
    
    def log *args
      p args
    end
    
    attr_accessor :answers, :amq
    
    def initialize
      @amq = MQ.new
      @answers = {}
      @amq.queue('reducer').subscribe{ |res|
        res = Marshal.load(res)
        log "got reduction from: #{res.from}"
        handle_result(res)
      }
    end
    
    def watch_for(answer)
      log "Reducer#watching for: #{answer}"
      @answers[answer.token] = answer
    end
    
    def handle_result(res)
      log "Reducer#handle_result: #{res}"
      reducer = @answers[res.token]
      if reducer
        reducer.handle_result(self,res)
      end
    end
    
  end  
end
