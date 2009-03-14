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
        intermediate_results_proc = lambda { |*args| self.handle_intermediate_results(actor, meth, deliverable, *args) }
        actor.send((meth.nil? ? :index : meth), deliverable.payload, &intermediate_results_proc)
      rescue Exception => e
        handle_exception(actor, meth, deliverable, e)
      end

      if deliverable.kind_of?(Request)
        result = Result.new(deliverable.token, deliverable.reply_to, result, identity)
        amq.queue(deliverable.reply_to, :no_declare => options[:secure]).publish(serializer.dump(result))
      end

      result
    end

    protected

    def handle_intermediate_results(actor, meth, deliverable, *args)
      case args.size
      when 1:
        messagekey = 'defaultkey'
        message = args.last
      when 2:
        messagekey = args.first.to_s
        message = args.last
      else
        raise ArgumentError, "handle_intermediate_results passed unexpected number of arguments (#{args.size})"
      end
      send_intermediate_results(actor, meth, deliverable, messagekey, message)
    end

    def send_intermediate_results(actor, meth, deliverable, messagekey, message)
      intermediate_message = IntermediateMessage.new(deliverable.token, deliverable.reply_to, identity, messagekey, message)
      amq.queue(deliverable.reply_to, :no_declare => options[:secure]).publish(serializer.dump(intermediate_message))
      intermediate_message
    end

    private

    def describe_error(e)
      "#{e.class.name}: #{e.message}\n #{e.backtrace.join("\n  ")}"
    end

    def handle_exception(actor, meth, deliverable, e)
      error = describe_error(e)
      Nanite::Log.error(error)
      begin
        if actor.class.exception_callback
          case actor.class.exception_callback
          when Symbol, String
            actor.send(actor.class.exception_callback, meth.to_sym, deliverable, e)
          when Proc
            actor.instance_exec(meth.to_sym, deliverable, e, &actor.class.exception_callback)
          end
        end
      rescue Exception => e1
        error = describe_error(e1)
        Nanite::Log.error(error)
      end
      error
    end
  end
end