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
    
  class Op
    attr_accessor :from, :payload, :type, :token, :resources, :reply_to
    def initialize(type, payload, *resources)
      @type, @payload, @resources = type, payload, resources.map{|r| Nanite::Resource.new(r)}
      @from = Nanite.user
    end
  end
    
  class Result
    attr_accessor :token, :results, :from, :to
    def initialize(token, to, from, results)
      @token = token
      @to = to
      @from = from
      @results = results
    end
  end
    
  class Register
    attr_accessor :name, :identity, :resources
    def initialize(name, identity, resources)
      @name = name
      @identity = identity
      @resources = resources
    end
  end  
    
  class Ping
    attr_accessor :from, :identity
    def initialize(from, identity)
      @from = from
      @identity = identity
    end
  end
  
  class Pong
    attr_accessor :ping
    def initialize(ping)
      @ping = ping
    end
  end
  
  class Advertise
    attr_accessor :token
    def initialize(ping)
      @ping = ping
    end
  end
  
end  
