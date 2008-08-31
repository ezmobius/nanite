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
        Nanite.pending.each do |k,v|
          if @token == v
            Nanite.callbacks[k].call(@results) if Nanite.callbacks[k]
            Nanite.pending.delete(k) 
            Nanite.callbacks.delete(k) 
          end    
        end
      end
    end
    
  end
end  