module Nanite
  class Agent

    def dump_packet(packet)
      if format == :json
        packet.to_json
      else
        Marshal.dump(packet)
      end
    end

    def load_packet(packet)
      if format == :json
        JSON.parse(packet)
      else
        Marshal.load(packet)
      end
    end

  end
end
