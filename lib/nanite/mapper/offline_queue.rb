# if deliverable.kind_of?(Request)
#   if job = job_warden.jobs[deliverable.token]
#     job.targets = targets
#   else
#     deliverable.reply_to = identity
#     job_warden.new_job(deliverable, targets)
#   end
# end

require 'nanite/helpers/routing_helper'
require 'nanite/cluster'

module Nanite
  class Mapper
    class OfflineQueue
      include Nanite::AMQPHelper
      include Nanite::Helpers::RoutingHelper
      include Nanite::Cluster

      attr_reader :serializer, :amqp, :options, :cluster

      def initialize(options = {})
        @serializer = Nanite::Serializer.new(options[:format])
        @offline_queue = 'mapper-offline'
        @options = options || {}
      end

      def run
        @amqp = start_amqp(options)
        setup_offline_queue
      end

      def setup_offline_queue
        offline_queue = amqp.queue(@offline_queue, :durable => true)
        offline_queue.subscribe(:ack => true) do |info, deliverable|
          deliverable = serializer.load(deliverable, :insecure)
          targets = targets_for(deliverable)
          unless targets.empty?
            Nanite::Log.debug("Recovering message from offline queue: #{deliverable.to_s([:from, :tags, :target])}")
            info.ack
            route(deliverable, targets)
          end
        end

        EM.add_periodic_timer(options[:offline_redelivery_frequency]) { offline_queue.recover }
      end
    end
  end
end
