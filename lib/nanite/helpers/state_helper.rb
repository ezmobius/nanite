module Nanite
  module Helpers
    module StateHelper
      def shared_state?
        true
      end

      def setup_state(options)
        return if $nanite_state
        case options
        when String
          # backwards compatibility, we assume redis if the configuration option
          # was a string
          Nanite::Log.info("[setup] using redis for state storage")
          require 'nanite/state'
          $nanite_state = Nanite::State.new(@state)
        when Hash
        else
          require 'nanite/local_state'
          $nanite_state = Nanite::LocalState.new
        end
      end
 
      def state
        $nanite_state
      end

      def nanites
        state
      end

      def reset_state
        $nanite_state.clear_state
      end
    end
  end
end
