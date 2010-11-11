module Nanite
  class Dispatcher
    attr_reader :registry, :serializer, :identity, :amq, :options
    attr_accessor :evmclass

    def initialize(amq, registry, serializer, identity, options)
      @amq = amq
      @registry = registry
      @serializer = serializer
      @identity = identity
      @options = options
      @evmclass = EM
      @evmclass.threadpool_size = (@options[:threadpool_size] || 20).to_i
    end

    def dispatch(header, deliverable)
      prefix, meth = deliverable.type.split('/')[1..-1]
      meth ||= :index
      actor = registry.actor_for(prefix)      

      operation = lambda do
        increment_running_jobs(deliverable)
        begin
          intermediate_results_proc = lambda { |*args| self.handle_intermediate_results(actor, meth, deliverable, *args) }
          args = [ deliverable.payload ]
          args.push(deliverable) if actor.method(meth).arity == 2

          ack_on_success = actor.acks_message_on_success meth
          header.ack unless ack_on_success
          result = actor.send(meth, *args, &intermediate_results_proc)
          header.ack if ack_on_success          
          result
        rescue Exception => e
          result = handle_exception(actor, meth, deliverable, e)
          header.reject(:requeue => true) if actor.requeues_message_on_failure meth
          result
        end
      end
      
      callback = lambda do |result|
        if deliverable.kind_of?(Request)
          result = Result.new(deliverable.token, deliverable.from, result, identity)
          Nanite::Log.debug("SEND #{result.to_s([])}")
          amq.queue(deliverable.reply_to, :no_declare => options[:secure]).publish(serializer.dump(result))
        end
        result
      end

      if @options[:single_threaded] || @options[:thread_poolsize] == 1
        @evmclass.next_tick { callback.call(operation.call) }
      else
        @evmclass.defer(operation, callback)
      end
    end

    protected

    def increment_running_jobs(job)
      EM.next_tick do
        Nanite::Actor.add_running_job(job)
        Nanite::Log.debug("Adding running job")
      end if options[:graceful]
    end
    
    def handle_intermediate_results(actor, meth, deliverable, *args)
      messagekey = case args.size
      when 1
        'defaultkey'
      when 2
        args.first.to_s
      else
        raise ArgumentError, "handle_intermediate_results passed unexpected number of arguments (#{args.size})"
      end
      message = args.last
      @evmclass.defer(lambda {
        [deliverable.reply_to, IntermediateMessage.new(deliverable.token, deliverable.from, identity, messagekey, message)]
      }, lambda { |r|
        amq.queue(r.first, :no_declare => options[:secure]).publish(serializer.dump(r.last))
      })
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
