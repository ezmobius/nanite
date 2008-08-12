module Nanite
  
  class Result
    attr_accessor :token, :results, :from, :to
    def initialize(token, to, from, results)
      @token = token
      @to = to
      @from = from
      @results = results
    end
  end

end  