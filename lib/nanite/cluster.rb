require 'nanite/helpers/routing_helper'

module Nanite
  module Cluster
    include Nanite::Helpers::RoutingHelper

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
        amqp.queue(target, :durable => true).publish(serializer.dump(request, enforce_format?(target)), :persistent => request.persistent)
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
