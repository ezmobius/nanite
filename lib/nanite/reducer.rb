module Nanite
  class Reducer
    attr_accessor :answers, :amq
    
    def initialize
      @responses = {}
    end
    
    def watch_for(packet)
      puts "watching for: #{packet}"
      @responses[packet.token] = packet
    end
    
    def handle_result(res)
      puts "reducer#handle_result: #{res.token}", @responses.keys
      if response = @responses[res.token]
        puts "got matching response: #{response}"
        if response.handle_result(res)
          puts "got final result"
          @responses.delete(res.token)
        end
      end  
    end
  end  
end
