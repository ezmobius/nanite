module Nanite

  # This class allows sending requests to nanite agents without having
  # to run a local mapper.
  # It is used by Actor.request which can be used by actors than need
  # to send requests to remote agents.
  # All requests go through the mapper for security purposes.
  class MapperProxy
        
    $:.push File.dirname(__FILE__)
    require 'amqp'
  
    include AMQPHelper
    
    attr_accessor :pending_requests, :identity, :options, :amqp, :serializer

    # Accessor for actor
    def self.instance
      @@instance
    end

    def initialize(id, opts)
      @options = opts || {}
      @identity = id
      @pending_requests = {}
      @amqp = start_amqp(options)
      @serializer = Serializer.new(options[:format])
      @@instance = self
    end

    # Send request to given agent through the mapper
    def request(type, payload = '', opts = {}, &blk)
      raise "Mapper proxy not initialized" unless identity && options
      request = Request.new(type, payload, opts)
      request.from = identity
      request.token = Identity.generate
      request.persistent = opts.key?(:persistent) ? opts[:persistent] : options[:persistent]
      pending_requests[request.token] = 
        { :intermediate_handler => opts[:intermediate_handler], :result_handler => blk }
      amqp.fanout('request', :no_declare => options[:secure]).publish(serializer.dump(request))
    end    
    
    # Handle intermediary result
    def handle_intermediate_result(res)
      handlers = pending_requests[res.token]
      handlers[:intermediate_handler].call(res) if handlers && handlers[:intermediate_handler]
    end
    
    # Handle final result
    def handle_result(res)
      handlers = pending_requests.delete(res.token)
      handlers[:result_handler].call(res) if handlers && handlers[:result_handler]
    end

  end
end
