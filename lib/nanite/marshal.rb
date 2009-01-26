require 'json'
require 'yaml'

module Nanite
  class Agent
    class DeserializationFailed < StandardError
      attr_accessor :packet, :serializers
      def initialize(packet, serializers)
        @packet, @serializers = packet, serializers
        super("Could not deserialize #{packet.inspect} using #{serializers}")
      end
    end

    def serializer
      @serializer ||= case format
      when :json
        JSON
      when :marshal
        Marshal
      when :yaml
        YAML
      else
        Marshal
      end
    end

    def dump_packet(packet)
      serializer.dump packet
    end

    def load_packet(packet)
      serializer.load packet
    rescue
      cascade_deserializers(packet) unless format
    end

    Supported = [Marshal, JSON, YAML]
    def cascade_deserializers(packet)
      Supported.find do |s|
        o = s.load(packet) rescue nil
        return o if o
      end
      raise DeserializationFailed.new(packet, Supported)
    end

  end
end