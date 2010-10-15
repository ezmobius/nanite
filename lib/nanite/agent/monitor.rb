module Nanite
  class Agent
    class Monitor
      include DaemonizeHelper
      
      attr_reader :agent, :options, :shutting_down, :pid_file
      
      def initialize(agent, options = {})
        @agent = agent
        @options = options
        setup_pid_file
        daemonize_agent if options[:daemonize]
        setup_traps
      end
      
      def setup_pid_file
        @pid_file = PidFile.new(agent.identity, options)
        @pid_file.check
      end
      
      def daemonize_agent
        daemonize(agent.identity, options)
        pid_file.write
      end
      
      def setup_traps
        ['INT', 'TERM'].each do |signal|
          trap signal do
            graceful_shutdown
          end
        end unless $TESTING
        
        trap 'USR1' do
          Nanite::Log.info("#{(Nanite::Actor.running_jobs || []).size} running jobs")
          Nanite::Log.info("Job list:\n#{(Nanite::Actor.running_jobs || []).collect{|job| "#{job.type}: #{job.payload[0..50]}"}}")
        end
      end
      
      def graceful_shutdown
        exit if shutting_down
        @shutting_down = true
        begin
          initiate_shutdown
        rescue
          Nanite::Log.error("Error during graceful shutdown: #{$!.message}\n#{$!.backtrace.join("\n")}")
          exit
        end
      end

      def cleanup
        pid_file.remove if options[:daemonize]
      end
      
      def initiate_shutdown
        cleanup
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
