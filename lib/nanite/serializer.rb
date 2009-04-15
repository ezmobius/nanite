module Nanite
  class Serializer

    class SerializationError < StandardError
      attr_accessor :action, :packet
      def initialize(action, packet)
        @action, @packet = action, packet
        super("Could not #{action} #{packet.inspect} using #{SERIALIZERS.keys.join(', ')}")
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
      @serializers.map do |serializer|
        o = serializer.send(action, packet) rescue nil
        return o if o
      end
      raise SerializationError.new(action, packet)
    end

  end # Serializer
end # Nanite
