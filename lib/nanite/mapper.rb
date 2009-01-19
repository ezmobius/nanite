module Nanite
  class Agent
    # Assigns a mapper to this agent.
    #
    # @api :public:
    def mapper=(map)
      @mapper = map
    end

    # Returns a mapper associated with this agent.
    #
    # @api :public:
    def mapper
      @mapper ||= Mapper.new(self)
    end

    # Make a nanite request which expects a response.
    #
    # ==== Parameters
    # type<String>:: The dispatch route for the request
    # payload<Object>:: Payload to send.  This will get marshalled en route
    #
    # ==== Options
    # :selector<Symbol>:: Method for selecting an actor.  Default is :least_loaded.
    #   :least_loaded:: Pick the nanite which has the lowest load.
    #   :all:: Send the request to all nanites which respond to the service.
    #   :random:: Randomly pick a nanite.
    #   :rr: Select a nanite according to round robin ordering.
    # :timeout<Numeric>:: The timeout in seconds before giving up on a response.
    #   Defaults to 60.
    # :target<String>:: Select a specific nanite via identity, rather than using
    #   a selector.
    #
    # ==== Block Parameters
    # :results<Object>:: The returned value from the nanite actor.
    #
    # @api :public:
    def request(type, payload="", opts = {}, &blk)
      mapper.request(type, payload, opts,  &blk)
    end

    # Make a nanite request which does not expect a response.
    #
    # ==== Parameters
    # type<String>:: The dispatch route for the request
    # payload<Object>:: Payload to send.  This will get marshalled en route
    #
    # ==== Options
    # :selector<Symbol>:: Method for selecting an actor.  Default is :least_loaded.
    #   :least_loaded:: Pick the nanite which has the lowest load.
    #   :all:: Send the request to all nanites which respond to the service.
    #   :random:: Randomly pick a nanite.
    #   :rr: Select a nanite according to round robin ordering.
    #
    # @api :public:
    def push(type, payload="", opts = {})
      mapper.push(type, payload, opts)
    end
  end

  # Mappers are control nodes in nanite clusters. Nanite clusters
  # can follow peer-to-peer model of communication as well as client-server,
  # and mappers are nodes that know who to send work requests to.
  #
  # Mappers can reside inside a front end web application written in Merb/Rails
  # and distribute heavy lifting to actors that register with the mapper as soon
  # as they go online.
  #
  # Each mapper tracks nanites registered with it. It periodically checks
  # when the last time a certain nanite sent a heartbeat notification,
  # and removes those that have timed out from the list of available workers.
  # As soon as a worker goes back online again it re-registers itself
  # and the mapper adds it to the list and makes it available to
  # be called again.
  #
  # This makes Nanite clusters self-healing and immune to individual node
  # failures.
  #
  # Nanites known to mapper are stored in a hash, where keys are nanite
  # identities (that you specify using the :identity option), and whose value
  # is a hash consisting of the triple representing timestamps/status/services.
  class Mapper
    attr_reader :agent, :nanites, :timeouts

    # Initializes mapper from agent instance.
    #
    # Initially nanites list is empty, and gets populated
    # as agents in the nanite cluster go online and advertise
    # their services.
    def initialize(agent)
      @identity = Nanite.gensym
      @agent = agent
      @nanites = {}
    end

    # Starts mapper operations. On start mapper sets up the following
    # queues with the AMQP broker:
    #
    # heartbeat#{identity} for heartbeat notifications
    # mapper#{identity} for registration notifications
    # identity value is used for messages queue (work requests queue) name
    #
    # Mapper tracks request timeouts in timeouts hash and when a request times out
    # the request token and a callback for it are deleted.
    #
    # @api :public:
    def start
      @timeouts = {}
      setup_queues
      agent.log.info "starting mapper with nanites(#{@nanites.keys.size}):\n#{@nanites.keys.join(',')}"
      EM.add_periodic_timer(agent.ping_time) do
        check_pings
        EM.next_tick { check_timeouts }
      end
    end

    # Message queue instance used for communication.
    # You are likely to not need direct access to AMQP
    # exchanges/queues, so this method is a part of plugin
    # API.
    # For documentation, see AMQP::MQ in amqp gem rdoc.
    #
    # @api :plugin:
    def amq
      @amq ||= MQ.new
    end

    # select nanite name/state pairs for those given block
    # returns true
    #
    # used by selectors specified to request messages
    #
    # @api :plugin:
    def select_nanites
      names = []
      @nanites.each do |name, state|
        names << [name, state] if yield(name, state)
      end
      names
    end

    # Assembles and routes a request packet to nanites
    # that satisfy given selector. Registers a callback
    # since this method assumes, you want to get results back.
    #
    # See Nanite::Mapper#request documentation for details
    # and available options.
    #
    # @api :plugin:
    def request(type, payload="", opts = {}, &blk)
      defaults = {:selector => :least_loaded, :timeout => 60}
      opts = defaults.merge(opts)
      req = Request.new(type, payload, agent.identity)
      req.token = Nanite.gensym
      req.reply_to = agent.identity
      answer = nil
      if target = opts[:target]
        answer = route_specific(req, target)
      else
        answer = route(req, opts[:selector])
      end
      return false unless answer
      agent.callbacks[answer.token] = blk if blk
      agent.reducer.watch_for(answer)
      @timeouts[answer.token] = (Time.now + (opts[:timeout] || 60) ) if opts[:timeout]
      answer.token
    end

    # Assembles and routes a request packet to nanites
    # that satisfy given selector. Registers a callback
    # since this method assumes, you want to get results back.
    #
    # See Nanite::Mapper#push documentation for details
    # and available options.
    #
    # @api :plugin:
    def push(type, payload="", opts = {:selector => :least_loaded, :timeout => 60})
      req = Request.new(type, payload, agent.identity)
      req.token = Nanite.gensym
      req.reply_to = nil
      if answer = route(req, opts[:selector])
        true
      else
        false
      end
    end

    private

    def setup_queues
      agent.log.debug "setting up queues"
      amq.queue("heartbeat#{@identity}", :exclusive => true).bind(amq.fanout('heartbeat')).subscribe{ |ping|
        agent.log.debug "Got heartbeat"
        handle_ping(agent.load_packet(ping))
      }
      amq.queue("mapper#{@identity}", :exclusive => true).bind(amq.fanout('registration')).subscribe{ |msg|
        agent.log.debug "Got registration"
        register(agent.load_packet(msg))
      }
      amq.queue(agent.identity, :exclusive => true).subscribe{ |msg|
        msg = agent.load_packet(msg)
        agent.log.debug "Got a message: #{msg.inspect}"
        agent.reducer.handle_result(msg)
      }
    end

    # updates nanite information (last ping timestamps, status)
    # when heartbeat message is received
    def handle_ping(ping)
      # from is Nanite's identity, see
      # Ping packet implementation in packets.rb
      if nanite = @nanites[ping.from]
        nanite[:timestamp] = Time.now
        nanite[:status] = ping.status
        amq.queue(ping.identity).publish(agent.dump_packet(Pong.new))
      else
        amq.queue(ping.identity).publish(agent.dump_packet(Advertise.new))
      end
    end

    # checks for nanites that timed out their heartbeat
    # notifications, and removes them from the list of
    # available workers
    def check_pings
      time = Time.now
      @nanites.each do |name, state|
        if (time - state[:timestamp]) > agent.ping_time + 1
          @nanites.delete(name)
          agent.log.info "removed #{name} from mapping/registration"
        end
      end
    end

    # adds nanite to nanites map: key is nanite's identity
    # and value is a timestamp/services/status triple implemented
    # as a hash
    def register(reg)
      @nanites[reg.identity] = {:timestamp => Time.now,
        :services => reg.services,
        :status    => reg.status}
      agent.log.info "registered: #{reg.identity}, #{@nanites[reg.identity]}"
    end

    # returns least loaded nanite that provides given service
    def least_loaded(res)
      candidates = select_nanites { |n,r| r[:services].include?(res) }
      return [] if candidates.empty?

      [candidates.min { |a,b|  a[1][:status] <=> b[1][:status] }]
    end

    # returns all nanites that provide given service
    def all(res)
      select_nanites { |n,r| r[:services].include?(res) }
    end

    def random(res)
      candidates = select_nanites { |n,r| r[:services].include?(res) }
      return [] if candidates.empty?

      [candidates[rand(candidates.size)]]
    end

    # selects next nanite that provides given resource
    # using round robin rotation
    def rr(res)
      @last ||= {}
      @last[res] ||= 0
      candidates = select_nanites { |n,r| r[:services].include?(res) }
      return [] if candidates.empty?
      @last[res] = 0 if @last[res] >= candidates.size
      candidate = candidates[@last[res]]
      @last[res] += 1
      [candidate]
    end

    # checks pending requests for expiration and removes
    # those that timed out
    def check_timeouts
      time = Time.now
      @timeouts.each do |tok, timeout|
        if time > timeout
          timeout = @timeouts.delete(tok)
          agent.log.info "request timeout: #{tok}"
          callback = agent.callbacks.delete(tok)
          callback.call(nil) if callback
        end
      end
    end

    # unicast routing method
    def route_specific(req, target)
      if @nanites[target]
        answer = Answer.new(agent,req.token)
        answer.workers = [target]

        EM.next_tick {
          send_request(req, target)
        }
        answer
      else
        nil
      end
    end

    # multicast routing method
    def route(req, selector)
      targets = __send__(selector, req.type)
      unless targets.empty?
        answer = Answer.new(agent, req.token)

        workers = targets.map{|t| t.first }

        answer.workers = Hash[*workers.zip(Array.new(workers.size, :waiting)).flatten]

        EM.next_tick {
          workers.each do |worker|
            send_request(req, worker)
          end
        }
        answer
      else
        nil
      end
    end

    # dumps packet and passes it to the "transport layer"
    def send_request(req, target)
      amq.queue(target).publish(agent.dump_packet(req))
    end
  end
end

