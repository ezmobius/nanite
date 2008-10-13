module Nanite
  class << self
    
    def push_to_exchange(type, domain, payload="")
      req = Nanite::Request.new(type, payload)
      req.token = Nanite.gensym
      req.reply_to = nil
      Nanite.amq.topic('push exchange').publish(Nanite.dump_packet(req), :key => "nanite.push.#{domain}")
    end    
    
    def subscribe_to_exchange(domain)
      Nanite.amq.queue("exchange#{Nanite.identity}").bind(Nanite.amq.topic('push exchange'), :key => "nanite.push.#{domain}").subscribe{ |packet|
        Nanite::Dispatcher.handle(Nanite.load_packet(packet))
      }
    end
  
  end  
end