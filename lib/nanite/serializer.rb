module Nanite
  class Serializer

    class SerializationError < StandardError
      attr_accessor :action, :packet
      def initialize(action, packet, serializers, msg = nil)
        @action, @packet = action, packet
        msg = ":\n#{msg}" if msg && !msg.empty?
        super("Could not #{action} #{packet.inspect} using #{serializers.inspect}#{msg}")
      end
    end # SerializationError

    # The secure serializer should not be part of the cascading
    def initialize(preferred_format = :marshal)
      preferred_format ||= :marshal
      if preferred_format.to_s == 'secure'
        @serializers = [ SecureSerializer ]
      else
        preferred_serializer = SERIALIZERS[preferred_format.to_sym]
        @serializers = SERIALIZERS.values.clone
        @serializers.unshift(@serializers.delete(preferred_serializer)) if preferred_serializer
      end
    end

    def dump(packet)
      cascade_serializers(:dump, packet)
    end

    def load(packet)
      cascade_serializers(:load, packet)
    end

    private

    SERIALIZERS = {:json => JSON, :marshal => Marshal, :yaml => YAML}.freeze

    def cascade_serializers(action, packet)
      errors = []
      @serializers.map do |serializer|
        begin
          o = serializer.send(action, packet)
        rescue Exception => e
          o = nil
          errors << "#{e.message}\n\t#{e.backtrace[0]}"
        end
        return o if o
      end
      raise SerializationError.new(action, packet, @serializers, errors.join("\n"))
    end

  end # Serializer
end # Nanite
