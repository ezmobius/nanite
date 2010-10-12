module Nanite
  class Cluster
    attr_reader :agent_timeout, :nanites, :reaper, :serializer, :identity, :amq, :redis, :mapper, :callbacks

    def initialize(amq, agent_timeout, identity, serializer, mapper, state_configuration=nil, callbacks = {})
      @amq = amq
      @agent_timeout = agent_timeout
      @identity = identity
      @serializer = serializer
      @mapper = mapper
      @state = state_configuration
      @security = SecurityProvider.get
      @callbacks = callbacks
      setup_state
      setup_queues
    end

    # determine which nanites should receive the given request
    def targets_for(request)
      return [request.target] if request.target
      __send__(request.selector, request.type, request.tags).collect {|name, state| name }
    end

   
    def route(request, targets)
      EM.next_tick { targets.map { |target| publish(request, target) } }
    end

    def publish(request, target)
      # We need to initialize the 'target' field of the request object so that the serializer has
      # access to it.
      begin
        old_target = request.target
        request.target = target unless target == 'mapper-offline'
        Nanite::Log.debug("SEND #{request.to_s([:from, :tags, :target])}")
        amq.queue(target).publish(serializer.dump(request, enforce_format?(target)), :persistent => request.persistent)
      ensure
        request.target = old_target
      end
    end

    protected

    def enforce_format?(target)
      target == 'mapper-offline' ? :insecure : nil
    end
    
    # updates nanite information (last ping timestamps, status)
    # when heartbeat message is received
   
   
    # forward response back to agent that originally made the request
    def forward_response(res, persistent)
      Nanite::Log.debug("SEND #{res.to_s([:to])}")
      amq.queue(res.to).publish(serializer.dump(res), :persistent => persistent)
    end
    
    # returns least loaded nanite that provides given service
    def least_loaded(service, tags=[])
      candidates = nanites_providing(service,tags)
      return [] if candidates.empty?

      [candidates.min { |a,b| a[1][:status] <=> b[1][:status] }]
    end

    # returns all nanites that provide given service
    def all(service, tags=[])
      nanites_providing(service,tags)
    end

    # returns a random nanite
    def random(service, tags=[])
      candidates = nanites_providing(service,tags)
      return [] if candidates.empty?

      [candidates[rand(candidates.size)]]
    end

    # selects next nanite that provides given service
    # using round robin rotation
    def rr(service, tags=[])
      @last ||= {}
      @last[service] ||= 0
      candidates = nanites_providing(service,tags)
      return [] if candidates.empty?
      @last[service] = 0 if @last[service] >= candidates.size
      candidate = candidates[@last[service]]
      @last[service] += 1
      [candidate]
    end
    
    def timed_out?(nanite)
      nanite[:timestamp].to_i < (Time.now.utc - agent_timeout).to_i
    end

    # returns all nanites that provide the given service
    def nanites_providing(service, *tags)
      nanites.nanites_for(service, *tags).delete_if do |nanite|
        nanite_id, nanite_attributes = nanite
        if timed_out?(nanite_attributes)
          reaper.unregister(nanite_id)
          nanites.delete(nanite_id)
          Nanite::Log.debug("Nanite #{nanite_id} timed out - ignoring in target selection and deleting from state - last seen at #{nanite_attributes[:timestamp]}")
        end
      end
    end

    def setup_queues
    end
   
    def setup_state
      case @state
      when String
        # backwards compatibility, we assume redis if the configuration option
        # was a string
        Nanite::Log.info("[setup] using redis for state storage")
        require 'nanite/state'
        @nanites = Nanite::State.new(@state)
      when Hash
      else
        require 'nanite/local_state'
        @nanites = Nanite::LocalState.new
      end
    end
    
    def shared_state?
      !@state.nil?
    end
  end
end
