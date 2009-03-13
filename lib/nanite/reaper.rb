module Nanite
  class Reaper

    def initialize(frequency=2)
      @timeouts = {}
      EM.add_periodic_timer(frequency) { EM.next_tick { reap } }
    end

    def timeout(token, seconds, &blk)
      @timeouts[token] = {:timestamp => Time.now + seconds, :seconds => seconds, :callback => blk}
    end

    def reset_with_autoregister_hack(token,seconds,&blk)
      unless @timeouts[token]
        timeout(token, seconds, &blk)
      end
      reset(token)
    end

    def reset(token)
      @timeouts[token][:timestamp] = Time.now + @timeouts[token][:seconds]
    end

    private

    def reap
      time = Time.now
      @timeouts.reject! do |token, data|
        if time > data[:timestamp]
          data[:callback].call
          true
        else
          false
        end
      end
    end
  end
end