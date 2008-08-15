module Nanite
  class Answer
    attr_accessor :token, :to, :results, :workers
    def initialize(token, to)
      @token = token
      @to = to
      @results = {}
    end
    
    def handle_result(res)
      @results[res.from] = res.results
      @workers.delete(res.from)
      if @workers.empty?
        Nanite.pending.each do |k,v|
          Nanite.results[k] = @results if @token == v
          Nanite.callbacks[k].call(@results) if Nanite.callbacks[k]
          Nanite.pending.delete(k) 
          Nanite.callbacks.delete(k)   
        end
        return true
      end
      nil
    end
    
  end
end  