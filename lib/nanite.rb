require 'rubygems'
require 'amqp'
require 'mq'
require 'json'
require 'logger'

$:.unshift File.dirname(__FILE__)
require 'extlib'
require 'nanite/packets'
require 'nanite/reducer'
require 'nanite/mapper'
require 'nanite/dispatcher'
require 'nanite/actor'
require 'nanite/streaming'
require 'nanite/exchanges'
require 'nanite/marshal'
require 'nanite/console'
require 'nanite/agent'

module Nanite

  VERSION = '0.2.0' unless defined?(Nanite::VERSION)

  class AgentNotRunning < StandardError; end

  class << self

    attr_reader :agent

    # Registers actor instance with given prefix
    def register(actor_instance, prefix = nil)
      @agent.register(actor_instance, prefix)
    end

    # Initializes a new agent and establishes
    # AMQP connection. To run agent as Mapper, pass :mapper => true.
    # This must be used inside EM.run block or if EventMachine reactor
    # is already started, for instance, by a Thin server that your Merb/Rails
    # application runs on.
    #
    # Agent options:
    #
    # identity    : identity of this agent, may be any string
    #
    # status_proc : a callable object that returns agent load as a string,
    #               defaults to load averages string extracted from `uptime`
    # format      : format to use for packets serialization. One of the two:
    #               :marshall or :json. Defaults to
    #               Ruby's Marshall format. For interoperability with
    #               AMQP clients implemented in other languages, use JSON.
    #
    #               Note that Nanite uses JSON gem,
    #               and ActiveSupport's JSON encoder may cause clashes
    #               if ActiveSupport is loaded after JSON gem.
    #
    # root        : application root for this agent, defaults to Dir.pwd
    #
    # log_dir     : path to directory where agent stores it's log file
    #               if not given, app_root is used.
    #
    # file_root   : path to directory to files this agent provides
    #               defaults to app_root/files
    #
    # ping_time   : time interval in seconds between two subsequent heartbeat messages
    #               this agent broadcasts. Default value is 15.
    #
    # log_file    : log file path, defaults to log_dir/nanite.[identity].log
    #
    # threaded_actors : when true, each message agent handles is handled in a separate thread
    #
    # console     : true tells Nanite to start interactive console
    #
    # daemonize   : true tells Nanite to daemonize
    #
    # services    : list of services provided by this agent, by default
    #               all methods exposed by actors are listed
    #
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
    #
    # On start Nanite reads config.yml, so it is common to specify
    # options in the YAML file. However, when both Ruby code options
    # and YAML file specify option, Ruby code options take precedence.
    #
    # Command line runner provided with Nanite out of the box parses
    # command line options and then uses this method, so it is safe to
    # consider it a single initialization point for every Nanite agent.
    #
    # @api :public:

    def start(options)
      @agent = Agent.new(options)
      @agent.start
      @agent
    end

    def request(*args, &blk)
      check_agent
      @agent.request(*args, &blk)
    end

    def push(*args, &blk)
      check_agent
      @agent.push(*args, &blk)
    end

    def log(*args)
      check_agent
      @agent.log(*args)
    end

    def gensym
      values = [
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x0010000),
        rand(0x1000000),
        rand(0x1000000),
      ]
      "%04x%04x%04x%04x%04x%06x%06x" % values
    end

    private
      def check_agent
        raise AgentNotRunning, "An agent needs to be started via Nanite.start" unless @agent
      end
  end
end

