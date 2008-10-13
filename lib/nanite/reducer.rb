module Nanite
  
  class Answer
    attr_accessor :token, :results, :workers
    def initialize(token)
      @token = token
      @results = {}
    end
    
    def handle_result(res)
      @results[res.from] = res.results
      @workers.delete(res.from)
      if @workers.empty?
        cback = Nanite.callbacks.delete(@token) 
        cback.call(@results) if cback
        true
      end
    end
  end
  
  class Reducer
    attr_accessor :answers, :amq
    
    def initialize
      @responses = {}
    end
    
    def watch_for(packet)
      @responses[packet.token] = packet
    end
    
    def handle_result(res)
      if response = @responses[res.token]
        if response.handle_result(res)
          @responses.delete(res.token)
        end
      end  
    end
  end  
end
