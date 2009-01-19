module Nanite
  # Represents reply to a work request from a particular node
  # in the nanite cluster.
  #
  # token is request unique identifier
  # agent is a node reply was received from
  class Answer
    attr_accessor :token, :results, :workers, :agent
    def initialize(agent,token)
      @token = token
      @agent = agent
      @results = {}
    end

    def handle_result(res)
      # pick a result from the node and remove sender
      # from the list of workers we are yet to receive reply
      # from
      @results[res.from] = res.results
      @workers.delete(res.from)
      # when all workers successfully replied, fire a callback
      # and delete request token from timeouts list
      if @workers.empty?
        cback = @agent.callbacks.delete(@token)
        cback.call(@results) if cback
        @agent.mapper.timeouts.delete(@token)
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
      # response here is an answer instance
      if response = @responses[res.token]
        if response.handle_result(res)
          @responses.delete(res.token)
        end
      end
    end
  end
end

