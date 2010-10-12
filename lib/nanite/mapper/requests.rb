module Nanite
  class Mapper
    class Requests
      include AMQPHelper
      include State

      def initialize(options = {})
        @options = options
      end

      def run
        setup_request_queue
      end

      def setup_request_queue
        handler = lambda do |msg|
          begin
            handle_request(serializer.load(msg))
          rescue Exception => e
            Nanite::Log.error("RECV [request] #{e.message}")
          end
        end
        req_fanout = amq.fanout('request', :durable => true)
        if shared_state?
          amq.queue("request").bind(req_fanout).subscribe &handler
        else
          amq.queue("request-#{identity}", :exclusive => true).bind(req_fanout).subscribe &handler
        end
      end


    end
  end
end
