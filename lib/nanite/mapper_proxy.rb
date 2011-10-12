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
      @@instance if defined?(@@instance)
    end

    def initialize(id, opts)
      @options = opts || {}
      @identity = id
      @pending_requests = {}
      @amqp = options[:amqp] || start_amqp(options)
      @serializer = Serializer.new(options[:format])
      @@instance = self
    end

    # Send request to given agent through the mapper
    def request(type, payload = '', opts = {}, &blk)
      raise "Mapper proxy not initialized" unless identity && options
      request = Request.new(type, payload, nil, opts)
      request.from = identity
      request.token = Identity.generate
      request.persistent = opts.key?(:persistent) ? opts[:persistent] : options[:persistent]
      pending_requests[request.token] = 
        { :intermediate_handler => opts[:intermediate_handler], :result_handler => blk }
      Nanite::Log.debug("SEND #{request.to_s([:tags, :target])}")
      amqp.fanout('request', {:durable => true, :no_declare => options[:secure]}).publish(serializer.dump(request))
    end    

    def push(type, payload = '', opts = {})
      raise "Mapper proxy not initialized" unless identity && options
      push = Push.new(type, payload, nil, opts)
      push.from = identity
      push.token = Identity.generate
      push.persistent = opts.key?(:persistent) ? opts[:persistent] : options[:persistent]
      Nanite::Log.debug("SEND #{push.to_s([:tags, :target])}")
      amqp.fanout('request', {:durable => true, :no_declare => options[:secure]}).publish(serializer.dump(push))
    end    
    
    # Handle intermediary result
    def handle_intermediate_result(res)
      handlers = pending_requests[res.token]
      handlers[:intermediate_handler].call(res.results) if handlers && handlers[:intermediate_handler]
    end
    
    # Handle final result
    def handle_result(res)
      handlers = pending_requests.delete(res.token)
      handlers[:result_handler].call(res.results) if handlers && handlers[:result_handler]
    end

  end
end
