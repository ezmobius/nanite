module Nanite

  class Answer
    attr_accessor :token, :results, :workers
    def initialize(token)
      @token = token
      @results = {}
    end

    def handle_result(agent, res)
      @results[res.from] = res.results
      @workers.delete(res.from)
      if @workers.empty?
        cback = agent.callbacks.delete(@token)
        cback.call(@results) if cback
        agent.mapper.timeouts.delete(@token)
        true
      end
    end
  end

  class Reducer
    attr_accessor :answers

    def initialize(agent)
      @agent = agent
      @responses = {}
    end

    def watch_for(packet)
      @responses[packet.token] = packet
    end

    def handle_result(res)
      if response = @responses[res.token]
        if response.handle_result(@agent, res)
          @responses.delete(res.token)
        end
      end
    end
  end
end

