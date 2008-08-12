module Nanite
  class Answer
    attr_accessor :token, :to, :results, :workers
    def initialize(token, to)
      @token = token
      @to = to
      @results = {}
    end
    
    def handle_result(reducer, res)
      p "Answer#handle_result: #{res}"
      @results[res.from] = res.results
      @workers.delete(res.from)
      if @workers.empty?
        reducer.amq.queue(@to).publish(Marshal.dump(Result.new(@token, @to, 'reducer', @results)))
        reducer.answers.delete(@token)
      end  
    end
    
  end
end  