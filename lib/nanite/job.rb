module Nanite
  class JobWarden
    attr_reader :serializer, :jobs

    def initialize(serializer)
      @serializer = serializer
      @jobs = {}
    end

    def new_job(request, targets, inthandler = nil, blk = nil)
      job = Job.new(request, targets, inthandler, blk)
      jobs[job.token] = job
      job
    end

    def process(msg)
      msg = serializer.load(msg)
      Nanite::Log.debug("processing message: #{msg.inspect}")

      if job = jobs[msg.token]
        job.process(msg)

        if job.intermediate_handler && (job.new_intermediate_state.size > 0)

          unless job.new_intermediate_state.size == 1
            raise "IntermediateMessages are currently dispatched as they arrive, shouldn't have more than one key in new_intermediate_state: #{job.new_intermediate_state.inspect}"
          end

          key = job.new_intermediate_state.first
          handler = job.intermediate_handler_for_key(key)
          if handler
            case handler.arity
            when 3
              handler.call(key, msg.from, job.intermediate_state[msg.from][key].last)
            when 4
              handler.call(key, msg.from, job.intermediate_state[msg.from][key].last, job)
            end
          end

          job.reset_pending_intermediate_state_keys
        end

        if job.completed?
          jobs.delete(job.token)
          if job.completed
            case job.completed.arity
            when 1
              job.completed.call(job.results)
            when 2
              job.completed.call(job.results, job)
            end
          end
        end

      end
    end
  end

  class Job
    attr_reader :results, :request, :token, :targets, :completed, :intermediate_state, :new_intermediate_state, :intermediate_handler

    def initialize(request, targets, inthandler = nil, blk = nil)
      @request = request
      @targets = targets
      @token = @request.token
      @results = {}
      @intermediate_handler = inthandler
      @new_intermediate_state = []
      @completed = blk
      @intermediate_state = {}
    end

    def process(msg)
      case msg
      when Result
        results[msg.from] = msg.results
        targets.delete(msg.from)
      when IntermediateMessage
        intermediate_state[msg.from] ||= {}
        intermediate_state[msg.from][msg.messagekey] ||= []
        intermediate_state[msg.from][msg.messagekey] << msg.message
        @new_intermediate_state << msg.messagekey
      end
    end

    def intermediate_handler_for_key(key)
      return nil unless @intermediate_handler
      case @intermediate_handler
      when Proc
        @intermediate_handler
      when Hash
        @intermediate_handler[key] || @intermediate_handler['*']
      end
    end

    def reset_pending_intermediate_state_keys
      @new_intermediate_state = []
    end

    def completed?
      targets.empty?
    end
  end
end