module Nanite
  class Mapper
    class Heartbeat
      include Nanite::Helpers::StateHelper
      include Nanite::AMQPHelper

      attr_reader :serializer, :options, :amqp, :callbacks, :identity

      def initialize(options = {})
        @serializer = Nanite::Serializer.new(options[:format])
        @security = SecurityProvider.get
        @options = options
        @callbacks = options[:callbacks] || {}
        @identity = options[:identity]
        setup_state(options[:state])
      end

      def run
        @amqp = start_amqp(options)
        #@reaper = Reaper.new(agent_timeout)
        setup_registration_queue
        setup_heartbeat_queue
      end

      # adds nanite to nanites map: key is nanite's identity
      # and value is a services/status pair implemented
      # as a hash
      def handle_registration(registration)
        case registration
        when Register
          if @security.authorize_registration(registration)
            Nanite::Log.debug("RECV #{registration.to_s}")
            nanites[registration.identity] = {:services => registration.services, :status => registration.status, :tags => registration.tags, :timestamp => Time.now.utc.to_i }
        #    reaper.register(registration.identity, agent_timeout + 1) { nanite_timed_out(registration.identity) }
            callbacks[:register].call(registration.identity, @mapper) if callbacks[:register]
          else
            Nanite::Log.warn("Received unauthorized registration: #{registration.to_s}")
          end
        when UnRegister
          Nanite::Log.info("RECV #{registration.to_s}")
          #reaper.unregister(registration.identity)
          nanites.delete(registration.identity)
          callbacks[:unregister].call(registration.identity, @mapper) if callbacks[:unregister]
        else
          Nanite::Log.warn("RECV [register] Invalid packet type: #{registration.class}")
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
            #reaper.update(ping.identity, agent_timeout + 1) { nanite_timed_out(ping.identity) }
          else
            packet = Advertise.new(nil, ping.identity)
            Nanite::Log.debug("SEND #{packet.to_s} to #{ping.identity}")
            amqp.queue(ping.identity, :durable => true).publish(serializer.dump(packet))
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
        heartbeat_fanout = amqp.fanout('heartbeat', :durable => true)
        if shared_state?
          amqp.queue("heartbeat").bind(heartbeat_fanout).subscribe(&handler)
        else
          amqp.queue("heartbeat-#{identity}", :exclusive => true).bind(heartbeat_fanout).subscribe(&handler)
        end
      end

      def setup_registration_queue
        handler = lambda do |msg|
          begin
            handle_registration(serializer.load(msg))
          rescue Exception => e
            Nanite::Log.error("RECV [register] #{e.message}")
          end
        end
        registration_fanout = amqp.fanout('registration', :durable => true)
        if shared_state?
          amqp.queue("registration").bind(registration_fanout).subscribe(&handler)
        else
          amqp.queue("registration-#{identity}", :exclusive => true).bind(registration_fanout).subscribe(&handler)
        end
      end
   
    end
  end
end
