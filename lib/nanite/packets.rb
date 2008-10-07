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
    
  class Request
    attr_accessor :from, :payload, :type, :token, :reply_to
    def initialize(type, payload)
      @type, @payload = type, payload
      @from = Nanite.identity
    end
  end
  
  class GetFile
    attr_accessor :from, :filename, :token, :services, :reply_to, :chunksize
    def initialize(file, service)
      @filename, @services = file, service
      @from = Nanite.identity
      @chunksize = 65536
    end
  end
    
  class Result
    attr_accessor :token, :results, :to, :from
    def initialize(token, to, results)
      @token = token
      @to = to
      @from = Nanite.identity
      @results = results
    end
  end
    
  class Register
    attr_accessor :identity, :services, :status
    def initialize(identity, services, status)
      @status = status
      @identity = identity
      @services = services
    end
  end  
    
  class Ping
    attr_accessor :identity, :status, :from
    def initialize(identity, status)
      @status = status
      @from = Nanite.identity
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
