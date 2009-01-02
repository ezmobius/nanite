module Nanite
  class << self

    def dump_packet(packet)
      if Nanite.format == :json
        packet.to_json
      else
        Marshal.dump(packet)
      end
    end

    def load_packet(packet)
      if Nanite.format == :json
        JSON.parse(packet)
      else
        Marshal.load(packet)
      end
    end

  end
end
