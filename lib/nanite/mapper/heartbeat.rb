module Nanite
  class Mapper
    class Heartbeat
      def run(options = {})
        setup_registration_queue
        setup_heartbeat_queue
      end
      # adds nanite to nanites map: key is nanite's identity
      # and value is a services/status pair implemented
      # as a hash
      def register(reg)
        case reg
        when Register
          if @security.authorize_registration(reg)
            Nanite::Log.debug("RECV #{reg.to_s}")
            nanites[reg.identity] = { :services => reg.services, :status => reg.status, :tags => reg.tags, :timestamp => Time.now.utc.to_i }
            reaper.register(reg.identity, agent_timeout + 1) { nanite_timed_out(reg.identity) }
            callbacks[:register].call(reg.identity, mapper) if callbacks[:register]
          else
            Nanite::Log.warn("RECV NOT AUTHORIZED #{reg.to_s}")
          end
        when UnRegister
          Nanite::Log.info("RECV #{reg.to_s}")
          reaper.unregister(reg.identity)
          nanites.delete(reg.identity)
          callbacks[:unregister].call(reg.identity, mapper) if callbacks[:unregister]
        else
          Nanite::Log.warn("RECV [register] Invalid packet type: #{reg.class}")
        end
      end

      def nanite_timed_out(token)
        nanite = nanites[token]
        if nanite && timed_out?(nanite)
          Nanite::Log.info("Nanite #{token} timed out")
          nanite = nanites.delete(token)
          callbacks[:timeout].call(token, mapper) if callbacks[:timeout]
          true
        end
      end

      def handle_ping(ping)
        begin
          if nanite = nanites[ping.identity]
            nanites.update_status(ping.identity, ping.status)
            reaper.update(ping.identity, agent_timeout + 1) { nanite_timed_out(ping.identity) }
          else
            packet = Advertise.new(nil, ping.identity)
            Nanite::Log.debug("SEND #{packet.to_s} to #{ping.identity}")
            amq.queue(ping.identity, :durable => true).publish(serializer.dump(packet))
          end
        end
      end

      def setup_heartbeat_queue
        handler = lambda do |ping|
          begin
            ping = serializer.load(ping)
            Nanite::Log.debug("RECV #{ping.to_s}") if ping.respond_to?(:to_s)
            handle_ping(ping)
          rescue Exception => e
            Nanite::Log.error("RECV [ping] #{e.message}")
          end
        end
        hb_fanout = amq.fanout('heartbeat', :durable => true)
        if shared_state?
          amq.queue("heartbeat").bind(hb_fanout).subscribe &handler
        else
          amq.queue("heartbeat-#{identity}", :exclusive => true).bind(hb_fanout).subscribe &handler
        end
      end

      def setup_registration_queue
        handler = lambda do |msg|
          begin
            register(serializer.load(msg))
          rescue Exception => e
            Nanite::Log.error("RECV [register] #{e.message}")
          end
        end
        reg_fanout = amq.fanout('registration', :durable => true)
        if shared_state?
          amq.queue("registration").bind(reg_fanout).subscribe &handler
        else
          amq.queue("registration-#{identity}", :exclusive => true).bind(reg_fanout).subscribe &handler
        end
      end
   
    end
  end
end
