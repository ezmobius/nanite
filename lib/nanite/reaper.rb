module Nanite
  class Reaper
    attr_reader :timeouts
    def initialize(frequency=2)
      @timeouts = {}
      EM.add_periodic_timer(frequency) { EM.next_tick { reap } }
    end

    # Add the specified token to the internal timeout hash.
    # The reaper will then check this instance on every reap.
    def register(token, seconds, &blk)
      @timeouts[token] = {:timestamp => Time.now + seconds, :seconds => seconds, :callback => blk}
    end
    
    def unregister(token)
      @timeouts.delete(token)
    end

    # Updates the timeout timestamp for the given token. If the token is
    # unknown to this reaper instance it will be auto-registered, usually
    # happening when you have several mappers and not all of them know
    # this agent yet, but received a ping from it.
    def update(token, seconds, &blk)
      unless @timeouts[token]
        register(token, seconds, &blk)
      end
      @timeouts[token][:timestamp] = Time.now + @timeouts[token][:seconds]
    end

    private

    def reap
      time = Time.now
      @timeouts.reject! do |token, data|
        time > data[:timestamp] and data[:callback].call
      end
    end
  end
end