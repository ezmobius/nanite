module Nanite
  # Mappers are control nodes in nanite clusters. Nanite clusters
  # can follow peer-to-peer model of communication as well as client-server,
  # and mappers are nodes that know who to send work requests to agents.
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
  class Mapper
    include AMQPHelper
    include ConsoleHelper
    include DaemonizeHelper

    attr_reader :cluster, :identity, :job_warden, :options, :serializer, :amq

    DEFAULT_OPTIONS = COMMON_DEFAULT_OPTIONS.merge({
      :user => 'mapper',
      :identity => Identity.generate,
      :agent_timeout => 15,
      :offline_redelivery_frequency => 10,
      :persistent => false,
      :offline_failsafe => false,
      :callbacks => {}
    }) unless defined?(DEFAULT_OPTIONS)

    # Initializes a new mapper and establishes
    # AMQP connection. This must be used inside EM.run block or if EventMachine reactor
    # is already started, for instance, by a Thin server that your Merb/Rails
    # application runs on.
    #
    # Mapper options:
    #
    # identity    : identity of this mapper, may be any string
    #
    # format      : format to use for packets serialization. Can be :marshal, :json or :yaml or :secure.
    #               Defaults to Ruby's Marshall format. For interoperability with
    #               AMQP clients implemented in other languages, use JSON.
    #
    #               Note that Nanite uses JSON gem,
    #               and ActiveSupport's JSON encoder may cause clashes
    #               if ActiveSupport is loaded after JSON gem.
    #
    #               Also using the secure format requires prior initialization of the serializer, see
    #               SecureSerializer.init
    #
    # log_level   : the verbosity of logging, can be debug, info, warn, error or fatal.
    #
    # agent_timeout   : how long to wait before an agent is considered to be offline
    #                   and thus removed from the list of available agents.
    #
    # log_dir    : log file path, defaults to the current working directory.
    #
    # console     : true tells mapper to start interactive console
    #
    # daemonize   : true tells mapper to daemonize
    #
    # pid_dir     : path to the directory where the agent stores its pid file (only if daemonized)
    #               defaults to the root or the current working directory.
    #
    # offline_redelivery_frequency : The frequency in seconds that messages stored in the offline queue will be retrieved
    #                                for attempted redelivery to the nanites. Default is 10 seconds.
    #
    # persistent  : true instructs the AMQP broker to save messages to persistent storage so that they aren't lost when the
    #               broker is restarted. Default is false. Can be overriden on a per-message basis using the request and push methods.
    #
    # secure      : use Security features of rabbitmq to restrict nanites to themselves
    #
    # prefetch    : Sets prefetch (only supported in RabbitMQ >= 1.6)
    # callbacks   : A set of callbacks to have code executed on specific events, supported events are :register,
    #               :unregister and :timeout. Parameter must be a hash with the corresponding events as keys and
    #               a block as value. The block will get the corresponding nanite's identity and a copy of the   
    #               mapper
    #
    # Connection options:
    #
    # vhost    : AMQP broker vhost that should be used
    #
    # user     : AMQP broker user
    #
    # pass     : AMQP broker password
    #
    # host     : host AMQP broker (or node of interest) runs on,
    #            defaults to 0.0.0.0
    #
    # port     : port AMQP broker (or node of interest) runs on,
    #            this defaults to 5672, port used by some widely
    #            used AMQP brokers (RabbitMQ and ZeroMQ)
    #
    # @api :public:
    def self.start(options = {})
      mapper = new(options)
      mapper.run
      mapper
    end

    def initialize(options)
      @options = DEFAULT_OPTIONS.clone.merge(options)
      root = options[:root] || @options[:root]
      custom_config = if root
        file = File.expand_path(File.join(root, 'config.yml'))
        File.exists?(file) ? (YAML.load(IO.read(file)) || {}) : {}
      else
        {}
      end
      options.delete(:identity) unless options[:identity]
      @options.update(custom_config.merge(options))
      @identity = "mapper-#{@options[:identity]}"
      @options[:file_root] ||= File.join(@options[:root], 'files')
      @options[:log_path] = false
      if @options[:daemonize]
        @options[:log_path] = (@options[:log_dir] || @options[:root] || Dir.pwd)
      end
      @options.freeze
      @offline_queue = 'mapper-offline'
    end

    def run
      setup_logging
      @serializer = Serializer.new(@options[:format])
      setup_process
      @amq = start_amqp(@options)
      @job_warden = JobWarden.new(@serializer)
      setup_cluster
      Nanite::Log.info('[setup] starting mapper')
      setup_queues
      start_console if @options[:console] && !@options[:daemonize]
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
    # :target<String>:: Select a specific nanite via identity, rather than using
    #   a selector.
    # :offline_failsafe<Boolean>:: Store messages in an offline queue when all
    #   the nanites are offline. Messages will be redelivered when nanites come online.
    #   Default is false unless the mapper was started with the --offline-failsafe flag.
    # :persistent<Boolean>:: Instructs the AMQP broker to save the message to persistent
    #   storage so that it isnt lost when the broker is restarted.
    #   Default is false unless the mapper was started with the --persistent flag.
    # :intermediate_handler:: Takes a lambda to call when an IntermediateMessage
    #   event arrives from a nanite.  If passed a Hash, hash keys should correspond to
    #   the IntermediateMessage keys provided by the nanite, and each should have a value
    #   that is a lambda/proc taking the parameters specified here.  Can supply a key '*'
    #   as a catch-all for unmatched keys.
    #
    # ==== Block Parameters for intermediate_handler
    # key<String>:: array of unique keys for which intermediate state has been received
    #   since the last call to this block.
    # nanite<String>:: nanite which sent the message.
    # state:: most recently delivered intermediate state for the key provided.
    # job:: (optional) -- if provided, this parameter gets the whole job object, if there's
    #   a reason to do more complex work with the job.
    #
    # ==== Block Parameters
    # :results<Object>:: The returned value from the nanite actor.
    #
    # @api :public:
    def request(type, payload = '', opts = {}, &blk)
      request = build_deliverable(Request, type, payload, opts)
      send_request(request, opts, &blk)
    end

    # Send request with pre-built request instance
    def send_request(request, opts = {}, &blk)
      request.reply_to = identity
      intm_handler = opts.delete(:intermediate_handler)
      targets = cluster.targets_for(request)
      if !targets.empty?
        job = job_warden.new_job(request, targets, intm_handler, blk)
        cluster.route(request, job.targets)
        job
      elsif offline_failsafe?(opts)
        job_warden.new_job(request, [], intm_handler, blk)
        cluster.publish(request, @offline_queue)
        :offline
      else
        false
      end
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
    # :offline_failsafe<Boolean>:: Store messages in an offline queue when all
    #   the nanites are offline. Messages will be redelivered when nanites come online.
    #   Default is false unless the mapper was started with the --offline-failsafe flag.
    # :persistent<Boolean>:: Instructs the AMQP broker to save the message to persistent
    #   storage so that it isnt lost when the broker is restarted.
    #   Default is false unless the mapper was started with the --persistent flag.
    #
    # @api :public:
    def push(type, payload = '', opts = {})
      push = build_deliverable(Push, type, payload, opts)
      send_push(push, opts)
    end

    def send_push(push, opts = {})
      targets = cluster.targets_for(push)
      if !targets.empty?
        cluster.route(push, targets)
        true
      elsif offline_failsafe?(opts)
        cluster.publish(push, @offline_queue)
        :offline
      else
        false
      end
    end
    
    def offline_failsafe?(opts)
      opts.key?(:offline_failsafe) ? opts[:offline_failsafe] : options[:offline_failsafe]
    end
    
    private

    def build_deliverable(deliverable_type, type, payload, opts)
      deliverable = deliverable_type.new(type, payload, nil, opts)
      deliverable.from = identity
      deliverable.token = Identity.generate
      deliverable.persistent = opts.key?(:persistent) ? opts[:persistent] : options[:persistent]
      deliverable
    end

    def setup_queues
      if amq.respond_to?(:prefetch) && @options.has_key?(:prefetch)
        amq.prefetch(@options[:prefetch])
      end

      setup_offline_queue
      setup_message_queue
    end

    def setup_offline_queue
      offline_queue = amq.queue(@offline_queue, :durable => true)
      offline_queue.subscribe(:ack => true) do |info, deliverable|
        deliverable = serializer.load(deliverable, :insecure)
        targets = cluster.targets_for(deliverable)
        unless targets.empty?
          Nanite::Log.debug("Recovering message from offline queue: #{deliverable.to_s([:from, :tags, :target])}")
          info.ack
          if deliverable.kind_of?(Request)
            if job = job_warden.jobs[deliverable.token]
              job.targets = targets
            else
              deliverable.reply_to = identity
              job_warden.new_job(deliverable, targets)
            end
          end
          cluster.route(deliverable, targets)
        end
      end

      EM.add_periodic_timer(options[:offline_redelivery_frequency]) { offline_queue.recover }
    end

    def setup_message_queue
      amq.queue(identity, {:secure => true}).bind(amq.fanout(identity)).subscribe do |msg|
        begin
          msg = serializer.load(msg)     
          Nanite::Log.debug("RECV #{msg.to_s}")
          job_warden.process(msg)
        rescue Exception => e
          Nanite::Log.error("RECV [result] #{e.message}")
        end
      end
    end

    def setup_logging
      Nanite::Log.init(@identity, @options[:log_path])
      Nanite::Log.level = @options[:log_level] if @options[:log_level]
    end

    def setup_cluster
      @cluster = Cluster.new(@amq, @options[:agent_timeout], @options[:identity], @serializer, self, @options[:redis], @options[:callbacks])
    end
    
    def setup_process
      pid_file = PidFile.new(@identity, @options)
      pid_file.check
      if @options[:daemonize]
        daemonize(@identity, @options)
        pid_file.write
        at_exit { pid_file.remove }
      else
        trap("INT") {exit}
      end
    end
  end
end

