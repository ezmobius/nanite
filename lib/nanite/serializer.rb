module Nanite
  class Serializer
    SERIALIZERS = {:json => JSON, :marshal => Marshal, :yaml => YAML}.freeze

    attr_reader :preferred_format
    
    class SerializationError < StandardError
      attr_accessor :action, :packet
      def initialize(action, packet, serializers, msg = nil)
        @action, @packet = action, packet
        msg = ":\n#{msg}" if msg && !msg.empty?
        super("Could not #{action} #{packet.inspect} using #{serializers.inspect}#{msg}")
      end
    end # SerializationError

    # The secure serializer should not be part of the cascading
    def initialize(preferred_format = nil)
      @preferred_format = preferred_format || :marshal
      if @preferred_format.to_s == 'secure'
        @serializers = [ SecureSerializer ]
      else
        preferred_serializer = SERIALIZERS[@preferred_format.to_sym]
        @serializers = SERIALIZERS.values.clone
        @serializers.unshift(@serializers.delete(preferred_serializer)) if preferred_serializer
      end
    end

    def dump(packet, format = nil)
      cascade_serializers(:dump, packet, format)
    end

    def load(packet, format = nil)
      cascade_serializers(:load, packet, format)
    end

    private

    def cascade_serializers(action, packet, format)
      errors = []
      determine_serializers(format).map do |serializer|
        begin
          serialized = serializer.send(action, packet)
        rescue Exception => e
          serialized = nil
          errors << "#{e.message}\n\t#{e.backtrace[0]}"
        end
        return serialized if serialized
      end
      raise SerializationError.new(action, packet, @serializers, errors.join("\n"))
    end
    
    def determine_serializers(format)
      if secure_serialization? and format == :insecure
        SERIALIZERS.values
      else
        @serializers
      end
    end
    
    def secure_serialization?
      @preferred_format.to_s == 'secure'
    end
    
  end
end