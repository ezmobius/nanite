module Nanite
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
