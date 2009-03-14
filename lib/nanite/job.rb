module Nanite
  class JobWarden
    attr_reader :serializer, :jobs

    def initialize(serializer)
      @serializer = serializer
      @jobs = {}
    end

    def new_job(request, targets, blk = nil)
      job = Job.new(request, targets, blk)
      jobs[job.token] = job
      job
    end

    def process(msg)
      msg = serializer.load(msg)
      Nanite::Log.debug("processing message: #{msg.inspect}")
      if job = jobs[msg.token]
        job.process(msg)
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
    attr_reader :results, :request, :token, :targets, :completed, :intermediate_state

    def initialize(request, targets, blk)
      @request = request
      @targets = targets
      @token = @request.token
      @results = {}
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
      end
    end

    def completed?
      targets.empty?
    end
  end
end