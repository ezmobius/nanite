module Nanite
  # Data transferred in nanites cluster must be serialized, right?
  # Nanite currently supports native Ruby marshalling and JSON to
  # interoperate with AMQP clients written in other languages.
  class Agent

    def dump_packet(packet)
      if format == :json
        packet.to_json
      else
        Marshal.dump(packet)
      end
    end

    def load_packet(packet)
      if packet[0] == 4
        Marshal.load(packet)
      else
        JSON.parse(packet)
      end
    end

  end
end
