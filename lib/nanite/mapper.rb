require "nanite/mapper/requests"
require "nanite/mapper/heartbeat"
require "nanite/mapper/offline_queue"
require "nanite/notifications/notification_center"
require "nanite/mapper/processor"

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
    include Nanite::Cluster
    include Nanite::Notifications::NotificationCenter

    attr_reader :identity, :options, :serializer, :amqp

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
      @offline_queue = 'mapper-offline'
    end

    def run
      setup_logging
      @serializer = Serializer.new(@options[:format])
      setup_process
      @amqp = start_amqp(@options)
      Nanite::Log.info('[setup] starting mapper')
      setup_queues
      register_callbacks
      setup_processors
      start_console if @options[:console] && !@options[:daemonize]
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


    # @api :private:
    def send_push(push, opts = {})
      targets = targets_for(push)
      if !targets.empty?
        route(push, targets)
        true
      elsif offline_failsafe?(opts)
        publish(push, @offline_queue)
        :offline
      else
        false
      end
    end

    # Send request with pre-built request instance
    #
    # @api :private:
    def send_request(request)
      request.reply_to = identity
      targets = targets_for(request)
      if targets.any?
        route(request, targets)
        true
      elsif offline_failsafe?
        publish(request, @offline_queue)
        :offline
      else
        false
      end
    end
    
    def offline_failsafe?(opts = {})
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
      if amqp.respond_to?(:prefetch) && @options.has_key?(:prefetch)
        amqp.prefetch(@options[:prefetch])
      end

      setup_message_queue
    end

    def setup_message_queue
      amqp.queue(identity, :exclusive => true).bind(amqp.fanout(identity)).subscribe do |msg|
        begin
          msg = serializer.load(msg)     
          Nanite::Log.debug("RECV #{msg.to_s}")
          case msg
          when Nanite::Result, Nanite::IntermediateMessage
            forward_response(msg)
          end
        rescue Exception => e
          Nanite::Log.error("RECV [result] #{e.message}")
        end
      end
    end

    def setup_logging
      Nanite::Log.init(@identity, @options[:log_path])
      Nanite::Log.level = @options[:log_level] if @options[:log_level]
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

    def setup_processors
      @processor = Nanite::Mapper::Processor.new(@options.update(:mapper => self, :amqp => @amqp)).run
    end

    # forward response back to agent that originally made the request
    def forward_response(response)
      Nanite::Log.debug("SEND #{response.to_s([:to])}")
      amqp.queue(response.to).publish(serializer.dump(response), :persistent => true)
    end

    def register_callbacks
      options[:callbacks].each do |event, block|
        notify(block, :on => event)
      end
    end
  end
end

