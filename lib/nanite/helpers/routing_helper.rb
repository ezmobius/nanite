require 'nanite/helpers/state_helper'

module Nanite
  module Helpers
    module RoutingHelper
      include StateHelper

      def timed_out?(nanite)
        nanite[:timestamp].to_i < (Time.now.utc - options[:agent_timeout]).to_i
      end

      def targets_for(request)
        return [request.target] if request.target
        __send__(request.selector, request.type, request.tags).collect {|name, state| name }
      end

      # returns least loaded nanite that provides given service
      def least_loaded(service, tags=[])
        candidates = nanites_providing(service,tags)
        return [] if candidates.empty?

        [candidates.min { |a,b| a[1][:status] <=> b[1][:status] }]
      end

      # returns all nanites that provide given service
      def all(service, tags=[])
        nanites_providing(service, tags)
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

      def nanites_providing(service, *tags)
        nanites.nanites_for(service, *tags).delete_if do |nanite|
          nanite_id, nanite_attributes = nanite
          if timed_out?(nanite_attributes)
            # TODO notify offline processing to stop monitoring or make the heartbeat checks more aware of it
            # being deleted from the state
      #      reaper.unregister(nanite_id)
            nanites.delete(nanite_id)
            Nanite::Log.debug("Nanite #{nanite_id} timed out - ignoring in target selection and deleting from state - last seen at #{nanite_attributes[:timestamp]}")
          end
        end
      end
    end
  end
end
