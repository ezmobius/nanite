module Nanite
  class Dispatcher
    attr_reader :registry, :serializer, :identity, :amq, :options

    def initialize(amq, registry, serializer, identity, options)
      @amq = amq
      @registry = registry
      @serializer = serializer
      @identity = identity
      @options = options
    end

    def dispatch(deliverable)
      result = begin
        prefix, meth = deliverable.type.split('/')[1..-1]
        actor = registry.actor_for(prefix)
        actor.send(meth, deliverable.payload)
      rescue Exception => e
        handle_exception(actor, meth, deliverable, e)
      end

      if deliverable.kind_of?(Request)
        result = Result.new(deliverable.token, deliverable.reply_to, result, identity)
        amq.queue(deliverable.reply_to, :no_declare => options[:secure]).publish(serializer.dump(result))
      end

      result
    end

    private

    def describe_error(e)
      "#{e.class.name}: #{e.message}\n #{e.backtrace.join("\n  ")}"
    end

    def handle_exception(actor, meth, deliverable, e)
      error = describe_error(e)
      Nanite::Log.error(error)
      begin
        if actor.class.instance_exception_callback
          case actor.class.instance_exception_callback
          when Symbol, String
            actor.send(actor.class.instance_exception_callback, meth.to_sym, deliverable, e)
          when Proc
            actor.instance_exec(meth.to_sym, deliverable, e, &actor.class.instance_exception_callback)
          end
        end
        if Nanite::Actor.superclass_exception_callback
          Nanite::Actor.superclass_exception_callback.call(actor, meth.to_sym, deliverable, e)
        end
      rescue Exception => e1
        error = describe_error(e1)
        Nanite::Log.error(error)
      end
      error
    end
  end
end