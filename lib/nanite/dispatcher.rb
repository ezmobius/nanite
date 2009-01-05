module Nanite
  class Dispatcher
    def initialize(agent)
      @agent = agent
      @actors = {}
    end

    attr_reader :agent, :actors

    def register(prefix, actor_instance)
      @actors[prefix.to_s] = actor_instance
    end

    def all_services
      @actors.map {|prefix,actor| actor.class.provides_for(prefix) }.flatten.uniq
    end

    def dispatch_request(req)
      _, prefix, meth = req.type.split('/')
      begin
        actor = @actors[prefix]
        res = actor.send(meth, req.payload)
      rescue Exception => e
        res = "#{e.class.name}: #{e.message}\n  #{e.backtrace.join("\n  ")}"
      end
      Result.new(req.token, req.reply_to, res, agent.identity) if req.reply_to
    end

    def handle(packet)
      case packet
      when Pong
        agent.log.debug "handling Pong: #{packet}"
        agent.pinged!
      when Advertise
        agent.log.debug "handling Advertise: #{packet}"
        agent.pinged!
        agent.advertise_services
      when Request
        agent.log.debug "handling Request: #{packet}"
        result = dispatch_request(packet)
        agent.amq.queue(packet.reply_to).publish(agent.dump_packet(result)) if packet.reply_to
      when Result
        agent.log.debug "handling Result: #{packet}"
        agent.reducer.handle_result(packet)
      end
    end
  end
end
