module Nanite
  # Dispatcher handles incoming messages and passes them
  # over to actors that handle them pretty much like controllers
  # in Rails and Merb handle HTTP requests.
  #
  # Dispatcher gathers provided services from actors running on the node
  # and has the list around so they can be advertised to mapper.
  #
  # Dispatcher directly sends work requests and sends replies back to request
  # sender's queue.
  #
  # Dispatcher works together with agent itself and reducer to do actual work
  # once packet type is determined and needs to be processed.
  class Dispatcher
    def initialize(agent)
      @agent = agent
      @actors = {}
    end

    attr_reader :agent, :actors

    def register(actor_instance, prefix = nil)
      raise ArgumentError, "#{actor_instance.inspect} is not a Nanite::Actor subclass instance" unless Nanite::Actor === actor_instance
      @agent.log.info "Registering #{actor_instance.inspect} with prefix #{prefix.inspect}"
      prefix ||= actor_instance.class.default_prefix
      @actors[prefix.to_s] = actor_instance
    end

    def all_services
      @actors.map {|prefix,actor| actor.class.provides_for(prefix) }.flatten.uniq
    end

    # When work request is received from a mapper, dispatcher picks an
    # actor and calls method on it passing it a payload.
    #
    # Result is sent back to the requesting node.
    def dispatch_request(req)
      # /calculator/add
      #
      # gets split into nil, calculator as prefix and add as method name
      # that is called on actor instance
      #
      # TODO: how about /math/calculator/add and handling namespaced
      #       actors or methods with / in them? It may be an issue for a larger
      #       nanites cluster :/
      _, prefix, meth = req.type.split('/')
      begin
        actor = @actors[prefix]
        res = actor.send((meth.nil? ? "index" : meth), req.payload)
      rescue Exception => e
        res = "#{e.class.name}: #{e.message}\n  #{e.backtrace.join("\n  ")}"
      end
      Result.new(req.token, req.reply_to, res, agent.identity) if req.reply_to
    end

    def handle(packet)
      case packet
      when Pong
        agent.log.debug "handling Pong: #{packet}"
        agent.pinged!
      when Advertise
        agent.log.debug "handling Advertise: #{packet}"
        agent.pinged!
        agent.advertise_services
      when Request
        agent.log.debug "handling Request: #{packet}"
        result = dispatch_request(packet)
        agent.amq.queue(packet.reply_to).publish(agent.dump_packet(result)) if packet.reply_to
      when Result
        agent.log.debug "handling Result: #{packet}"
        agent.reducer.handle_result(packet)
      end
    end
  end
end
