module Nanite
  class Agent
    def push_to_exchange(type, domain, payload="")
      req = Request.new(type, payload, identity)
      req.token = Nanite.gensym
      req.reply_to = nil
      amq.topic('push exchange').publish(dump_packet(req), :key => "nanite.push.#{domain}")
    end

    def subscribe_to_exchange(domain)
      amq.queue("exchange#{identity}").bind(amq.topic('push exchange'), :key => "nanite.push.#{domain}").subscribe{ |packet|
        dispatcher.handle(load_packet(packet))
      }
    end
  end
end
