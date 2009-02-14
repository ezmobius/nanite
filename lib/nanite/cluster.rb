module Nanite
  class Cluster
    attr_reader :agent_timeout, :nanites, :reaper, :amq, :log, :serializer, :identity

    def initialize(agent_timeout, identity, amq, log, serializer)
      @agent_timeout = agent_timeout
      @identity = identity
      @amq = amq
      @serializer = serializer
      @nanites = {}
      @reaper = Reaper.new(agent_timeout)
      @log = log
      setup_queues
    end

    # determine which nanites should receive the given request
    def targets_for(request)
      return [request.target] if request.target
      __send__(request.selector, request.type).collect {|name, state| name }
    end

    # updates nanite information (last ping timestamps, status)
    # when heartbeat message is received
    def handle_ping(ping)
      if nanite = nanites[ping.identity]
        nanite[:status] = ping.status
        reaper.reset(ping.identity)
      else
        amq.queue(ping.identity).publish(serializer.dump(Advertise.new))
      end
    end

    # adds nanite to nanites map: key is nanite's identity
    # and value is a timestamp/services/status triple implemented
    # as a hash
    def register(reg)
      nanites[reg.identity] = {:services => reg.services, :status => reg.status}
      reaper.timeout(reg.identity, agent_timeout + 1) { nanites.delete(reg.identity) }
      log.info "registered: #{reg.identity}, #{nanites[reg.identity]}"
    end

    protected

    # returns least loaded nanite that provides given service
    def least_loaded(res)
      candidates = nanites_providing(res)
      return [] if candidates.empty?

      [candidates.min { |a,b|  a[1][:status] <=> b[1][:status] }]
    end

    # returns all nanites that provide given service
    def all(res)
      nanites_providing(res)
    end

    # returns a random nanite
    def random(res)
      candidates = nanites_providing(res)
      return [] if candidates.empty?

      [candidates[rand(candidates.size)]]
    end

    # selects next nanite that provides given resource
    # using round robin rotation
    def rr(res)
      @last ||= {}
      @last[res] ||= 0
      candidates = nanites_providing(res)
      return [] if candidates.empty?
      @last[res] = 0 if @last[res] >= candidates.size
      candidate = candidates[@last[res]]
      @last[res] += 1
      [candidate]
    end

    # returns all nanites that provide the given service
    def nanites_providing(service)
      providing = []
      nanites.each do |name, state|
        providing << [name, state] if state[:services].include?(service)
      end
      providing
    end

    def setup_queues
      setup_heartbeat_queue
      setup_registration_queue
    end

    def setup_heartbeat_queue
      amq.queue("heartbeat-#{identity}", :exclusive => true).bind(amq.fanout('heartbeat')).subscribe do |ping|
        log.debug('got heartbeat')
        handle_ping(serializer.load(ping))
      end
    end

    def setup_registration_queue
      amq.queue("registration-#{identity}", :exclusive => true).bind(amq.fanout('registration')).subscribe do |msg|
        log.debug('got registration')
        register(serializer.load(msg))
      end
    end
  end
end
