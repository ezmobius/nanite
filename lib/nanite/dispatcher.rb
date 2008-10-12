module Nanite
  class Dispatcher
    class << self
      def register(actor_instance)
        (@actors ||= []) << actor_instance
      end
      
      def all_services
        (@actors||[]).map {|a| a.provides }.flatten.uniq
      end
    
      def dispatch_request(op)
        _, actor, meth = op.type.split('/')
        begin
          actor = Object.full_const_get(actor.camel_case)
          actor = @actors.select{|a| actor === a }.first
          res = actor.send(meth, op.payload)
        rescue Exception => e
          res = "#{e.class.name}: #{e.message}\n  #{e.backtrace.join("\n  ")}"
        end
        Nanite::Result.new(op.token, op.reply_to, res) if op.reply_to 
      end    
            
      def handle(packet)
        case packet
        when Nanite::Pong
          Nanite.last_ping = Time.now
        when Nanite::Advertise
          Nanite.last_ping = Time.now
          Nanite.advertise_services
        when Nanite::Request
          result = dispatch_request(packet)
          Nanite.amq.queue(packet.reply_to).publish(Marshal.dump(result))
        when Nanite::Result
          Nanite.reducer.handle_result(packet)
        end
      end
      
      def match?(required_service, provided_services)
        provided_services.any? do |r|
          r == required_service
        end
      end
    end    
  end

end