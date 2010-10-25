require 'nanite/notifications/notification_center'

module Nanite
  class Mapper
    class Heartbeat
      include Nanite::Helpers::StateHelper
      include Nanite::AMQPHelper
      include Nanite::Notifications::NotificationCenter

      attr_reader :serializer, :options, :amqp, :identity, :running

      def initialize(options = {})
        @serializer = Nanite::Serializer.new(options[:format])
        @security = Nanite::SecurityProvider.get
        @options = options
        @identity = options[:identity]
        setup_state(options[:state])
      end

      def run
        @amqp = options[:amqp] || start_amqp(options)
        setup_registration_queue
        setup_heartbeat_queue
        @running = true
      end

      # adds nanite to nanites map: key is nanite's identity
      # and value is a services/status pair implemented
      # as a hash
      def handle_registration(registration)
        case registration
        when Nanite::Register
          if @security.authorize_registration(registration)
            Nanite::Log.debug("RECV #{registration.to_s}")
            nanites[registration.identity] = {:services => registration.services, :status => registration.status, :tags => registration.tags, :timestamp => Time.now.utc.to_i }
            trigger(:register, registration.identity)
          else
            Nanite::Log.warn("Received unauthorized registration: #{registration.to_s}")
          end
        when Nanite::UnRegister
          Nanite::Log.info("RECV #{registration.to_s}")
          trigger(:unregister, registration.identity)
          nanites.delete(registration.identity)
        else
          Nanite::Log.warn("RECV [register] Invalid packet type: #{registration.class}")
        end
      end

      def nanite_timed_out(identity)
        nanite = nanites[identity]
        if nanite && timed_out?(nanite)
          Nanite::Log.info("Nanite #{identity} timed out")
          nanite = nanites.delete(identity)
          true
        end
      end

      def timed_out?(nanite)
        nanite[:timestamp].to_i < (Time.now.utc - options[:agent_timeout]).to_i
      end

      def handle_ping(ping)
        begin
          if nanite = nanites[ping.identity]
            nanites.update_status(ping.identity, ping.status)
          else
            packet = Nanite::Advertise.new(nil, ping.identity)
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
