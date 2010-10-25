module Nanite
  class Reaper
    include Nanite::Notifications::NotificationCenter

    attr_reader :timeouts
    def initialize(timeout_after = 2)
      @timeout_after = timeout_after
      @timeouts = {}
      notify(:register, :on => :register)
      notify(:unregister, :on => :unregister)
      notify(:update_or_register, :on => :ping)
      EM.add_periodic_timer(timeout_after) { EM.next_tick { reap } }
    end

    # Add the specified token to the internal timeout hash.
    # The reaper will then check this instance on every reap.
    def register(identity)
      @timeouts[identity] = {:timestamp => Time.now + @timeout_after, :seconds => @timeout_after + 1}
    end
    
    def unregister(identity)
      @timeouts.delete(identity)
    end

    # Updates the timeout timestamp for the given token. If the token is
    # unknown to this reaper instance it will be auto-registered, usually
    # happening when you have several mappers and not all of them know
    # this agent yet, but received a ping from it.
    def update_or_register(identity)
      unless @timeouts[identity]
        register(identity)
      end
      @timeouts[identity][:timestamp] = Time.now + @timeouts[identity][:seconds]
    end

    private

    def reap
      time = Time.now
      @timeouts.reject! do |identity, data|
        time > data[:timestamp] and trigger(:timeout, identity, nil)
      end
    end
  end
end
