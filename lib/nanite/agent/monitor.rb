module Nanite
  class Agent
    class Monitor
      attr_reader :agent, :options
      
      def initialize(agent, options = {})
        @agent = agent
        @options = options
        ['INT', 'TERM'].each do |signal|
          trap signal do
            graceful_shutdown
          end
        end unless $TESTING
      end
      
      def graceful_shutdown
        exit if @shutting_down
        @shutting_down = true
        begin
          initiate_shutdown
        rescue
          Nanite::Log.error("Error during graceful shutdown: #{$!.message}\n#{$!.backtrace.join("\n")}")
          exit
        end
      end

      def initiate_shutdown
        agent.unsubscribe
        agent.un_register
        wait_for_running_actors do
          shutdown
        end
      end
      
      def shutdown
        agent.disconnect
        EM.add_timer(0.5) do
          EM.stop
          exit
        end
      end
    
      def wait_for_running_actors(&blk)
        if options[:graceful] and Nanite::Actor.running_jobs?
          Nanite::Log.info("Waiting for running jobs to finish")
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