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
      prefix, meth = deliverable.type.split('/')[1..-1]
      actor = registry.actor_for(prefix)

      EM.defer lambda {
        begin
          intermediate_results_proc = lambda { |*args| self.handle_intermediate_results(actor, meth, deliverable, *args) }
          actor.send((meth.nil? ? :index : meth), deliverable.payload, &intermediate_results_proc)
        rescue Exception => e
          handle_exception(actor, meth, deliverable, e)
        end
      }, lambda { |r|
        if deliverable.kind_of?(Request)
          r = Result.new(deliverable.token, deliverable.reply_to, r, identity)
          amq.queue(deliverable.reply_to, :no_declare => options[:secure]).publish(serializer.dump(r))
        end
        r
      }
    end

    protected

    def handle_intermediate_results(actor, meth, deliverable, *args)
      messagekey = case args.size
      when 1:
        'defaultkey'
      when 2:
        args.first.to_s
      else
        raise ArgumentError, "handle_intermediate_results passed unexpected number of arguments (#{args.size})"
      end
      message = args.last
      EM.defer lambda {
        [deliverable.reply_to, IntermediateMessage.new(deliverable.token, deliverable.reply_to, identity, messagekey, message)]
      }, lambda { |r|
        amq.queue(r.first, :no_declare => options[:secure]).publish(serializer.dump(r.last))
      }
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