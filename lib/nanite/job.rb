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
          job.completed.call(job.results) if job.completed
        end
      end
    end
  end

  class Job
    attr_reader :results, :request, :token, :targets, :completed

    def initialize(request, targets, blk)
      @request = request
      @targets = targets
      @token = @request.token
      @results = {}
      @completed = blk
    end

    def process(msg)
      results[msg.from] = msg.results
      targets.delete(msg.from)
    end

    def completed?
      targets.empty?
    end
  end
end