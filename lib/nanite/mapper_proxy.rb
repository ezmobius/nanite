module Nanite

  # This class should be used by agents to send requests
  class MapperProxy
    
    # Make a nanite request which expects a response.
    # See Mapper.request for more information.
    def self.request(identity, type, payload = '', opts = {}, &blk)
      raise "Mapper proxy not initialized" unless @identity && @options
      request = Request.new(type, payload, opts)
      request.from = @identity
      request.token = Identity.generate
      request.persistent = opts.key?(:persistent) ? opts[:persistent] : @options[:persistent]
      @pending_requests ||= {}
      @pending_requests[request.token] = 
        { :intermediate_handler => opts[:intermediate_handler], :result_handler => blk }
      amq.fanout('request', :no_declare => @options[:secure]).publish(serializer.dump(request))
    end
    
    # Set agent identity
    def self.identity=(identity)
      @identity = identity
    end
 
    # Agent options
    def self.options=(opts)
      @options = opts || {}
    end
    
    # Handle intermediary result
    def self.handle_intermediate_result(res)
      handlers = @pending_request[res.token]
      handlers[:intermediate_handler].call(res) if handlers && handlers[:intermediate_handler]
    end
    
    # Handle final result
    def self.handle_result(res)
      handlers = @pending_request.delete(res.token)
      handlers[:result_handler].call(res) if handlers && handlers[:result_handler]
    end
  
  end
  
end