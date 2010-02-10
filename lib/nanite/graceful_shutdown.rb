module Nanite
  class Agent
    module GracefulShutdown
      def graceful_shutdown
        exit if @shutting_down
        begin
          @shutting_down = true
          unsubscribe
          wait_for_running_actors do
            shutdown
          end
        rescue
          Nanite::Log.error($!.message)
          exit
        end
      end

      def unsubscribe
        @heartbeat_timer.cancel
        amqp.queue('heartbeat').unsubscribe
        amqp.queue(identity).unsubscribe
        un_register
      end
    
      def disconnect
        amqp.close_connection
        @mapper_proxy.amqp.close_connection
      end
    
      def shutdown
        disconnect
        EM.add_timer(0.5) do
          EM.stop
          exit
        end
      end
    
      def wait_for_running_actors(&blk)
        if options[:wait_on_exit]
          Nanite::Log.info("Waiting for running jobs to finish") if Nanite::Actor.running_jobs?
          timer = EM.add_periodic_timer(1) do
            unless Nanite::Actor.running_jobs?
              timer.cancel
              blk.call
            end
          end
        else
          blk.call
        end
      end
    end
  end
end