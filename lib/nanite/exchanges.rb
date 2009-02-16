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
      request = Request.new(type, payload)
      request.from = identity
      request.token = Identity.generate
      amq.topic('push exchange').publish(serializer.dump(request), :key => "nanite.push.#{domain}")
    end

    def subscribe_to_exchange(domain)
      amq.queue("exchange-#{identity}").bind(amq.topic('push exchange'), :key => "nanite.push.#{domain}").subscribe do |packet|
        # ??? Is this old code or what?
      end
    end
  end
end
