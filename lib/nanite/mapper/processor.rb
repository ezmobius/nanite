module Nanite
  class Mapper
    class Processor
      attr_reader :options, :heartbeat, :offline_queue, :requests

      def initialize(options = {})
        @options = options
      end

      def run
        start_heartbeat
        start_requests
        start_offline_queue if @options[:offline_failsafe]
      end

      def start_heartbeat
        @heartbeat = Nanite::Mapper::Heartbeat.new(options)
        @heartbeat.run
      end

      def start_requests
        @requests = Nanite::Mapper::Requests.new(options)
        @requests.run
      end

      def start_offline_queue
        @offline_queue = Nanite::Mapper::OfflineQueue.new(options)
        @offline_queue.run
      end
    end
  end
end
