module Nanite
  class Serializer
    SERIALIZERS = {:json => JSON, :marshal => Marshal, :yaml => YAML}

    class SerializationError < StandardError
      attr_accessor :action, :packet
      def initialize(action, packet)
        @action, @packet = action, packet
        super("Could not #{action} #{packet.inspect} using #{SERIALIZERS.keys.join(', ')}")
      end
    end

    def initialize(format)
      preferred_serializer = format ? SERIALIZERS[format.to_sym] : Marshal
      @serializers = SERIALIZERS.values.clone
      @serializers.delete(preferred_serializer)
      @serializers.unshift(preferred_serializer)
    end

    def dump(packet)
      cascade_serializers(:dump, packet)
    end

    def load(packet)
      cascade_serializers(:load, packet)
    end

    private

    def cascade_serializers(action, packet)
      @serializers.map do |serializer|
        o = serializer.send(action, packet) rescue nil
        return o if o
      end
      raise SerializationError.new(action, packet)
    end
  end
end