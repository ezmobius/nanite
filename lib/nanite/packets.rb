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
  
  class FileReceive
    attr_accessor :token, :worker
    def initialize(token)
      @token = token
    end
    
    def handle_result(res)
      ret = false
      Nanite.pending.each do |k,v|
        if @token == v
          Nanite.callbacks[k].call(res.results) if Nanite.callbacks[k]
          unless res.results
            Nanite.pending.delete(k) 
            Nanite.callbacks.delete(k)
            ret = true
          end
        end    
      end
      ret
    end
    
  end
    
  class FileStart
    attr_accessor :filename, :token, :dest
    def initialize(filename, dest)
      @filename = filename
      @dest = dest
      @token = Nanite.gen_token
    end  
  end
  
  class FileEnd
    attr_accessor :token
    def initialize(token)
      @token = token
    end  
  end
  
  class FileChunk
    attr_accessor :chunk, :token
    def initialize(token, chunk=nil)
      @chunk = chunk
      @token = token
    end  
  end
    
  class Op
    attr_accessor :from, :payload, :type, :token, :resources, :reply_to
    def initialize(type, payload, *resources)
      @type, @payload, @resources = type, payload, resources.map{|r| Nanite::Resource.new(r)}
      @from = Nanite.user
    end
  end
  
  class GetFile
    attr_accessor :from, :filename, :token, :resources, :reply_to, :chunksize
    def initialize(file, *resources)
      @filename, @resources = file, resources.map{|r| Nanite::Resource.new(r)}
      @from = Nanite.user
      @chunksize = 65536
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
