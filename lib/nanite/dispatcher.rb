module Nanite
  class Dispatcher
    attr_reader :registry, :serializer, :identity, :log, :amq, :options

    def initialize(amq, registry, serializer, identity, log, options)
      @amq = amq
      @registry = registry
      @serializer = serializer
      @identity = identity
      @log = log
      @options = options
    end

    def dispatch(deliverable)
      result = begin
        act_upon(deliverable)
      rescue Exception => e
        error = "#{e.class.name}: #{e.message}\n #{e.backtrace.join("\n  ")}"
        log.error(error)
        error
      end

      if deliverable.kind_of?(Request)
        result = Result.new(deliverable.token, deliverable.reply_to, result, identity)
        amq.queue(deliverable.reply_to, :no_declare => options[:secure]).publish(serializer.dump(result))
      end

      result
    end

    private

    def act_upon(deliverable)
      prefix, meth = deliverable.type.split('/')[1..-1]
      actor = registry.actor_for(prefix)
      actor.send(meth, deliverable.payload)
    end
  end
end