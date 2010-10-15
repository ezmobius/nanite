require 'nanite/helpers/routing_helper'

module Nanite
  module Cluster
    include Nanite::Helpers::RoutingHelper

    attr_reader :agent_timeout, :serializer, :identity, :amqp

    def initialize(amqp, identity, serializer, state_configuration=nil)
      @amqp = amqp
      @identity = identity
      @serializer = serializer
      @state = state_configuration
      @security = SecurityProvider.get
      setup_state(state_configuration)
    end

    def route(request, targets)
      EM.next_tick do
        targets.map {|target| publish(request, target) }
      end
    end

    def publish(request, target)
      # We need to initialize the 'target' field of the request object so that the serializer has
      # access to it.
      begin
        old_target = request.target
        request.target = target unless target == 'mapper-offline'
        Nanite::Log.debug("SEND #{request.to_s([:from, :tags, :target])}")
        amqp.queue(target).publish(serializer.dump(request, enforce_format?(target)), :persistent => request.persistent)
      ensure
        request.target = old_target
      end
    end

    protected

    def enforce_format?(target)
      target == 'mapper-offline' ? :insecure : nil
    end
    
   
  end
end
