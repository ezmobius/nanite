module Nanite
  # Using these methods actors can participate in distributed processing
  # with other nodes using topic exchange publishing (classic pub/sub with
  # matching)
  #
  # This lets you handle a work to do to a single agent from a mapper in your
  # Merb/Rails app, and let agents self-organize who does what, as long as they
  # properly collect the result to return it to the requesting peer.
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
