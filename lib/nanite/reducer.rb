#AMQP.logging = true
module Nanite
      
  class Reducer
    
    def log *args
      p args
    end
    
    attr_accessor :answers, :amq
    
    def initialize
      @answers = {}
    end
    
    def watch_for(answer)
      @answers[answer.token] = answer
    end
    
    def handle_result(res)
      answer = @answers[res.token]
      if answer
        if answer.handle_result(res)
          @answers.delete(res.token)
        end  
      end
    end
    
  end  
end
