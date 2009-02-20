require 'rubygems'
require 'amqp'
require 'mq'
require 'json'
require 'logger'
require 'yaml'

$:.unshift File.dirname(__FILE__)
require 'nanite/amqp'
require 'nanite/util'
require 'nanite/config'
require 'nanite/packets'
require 'nanite/identity'
require 'nanite/console'
require 'nanite/daemonize'
require 'nanite/job'
require 'nanite/mapper'
require 'nanite/actor'
require 'nanite/actor_registry'
require 'nanite/streaming'
require 'nanite/dispatcher'
require 'nanite/agent'
require 'nanite/cluster'
require 'nanite/reaper'
require 'nanite/serializer'
require 'nanite/log'

module Nanite
  VERSION = '0.3.0' unless defined?(Nanite::VERSION)

  class MapperNotRunning < StandardError; end

  class << self
    attr_reader :mapper, :agent

    def start_agent(options = {})
      @agent = Nanite::Agent.start(options)
    end

    def start_mapper(options = {})
      @mapper = Nanite::Mapper.start(options)
    end

    def request(*args, &blk)
      ensure_mapper
      @mapper.request(*args, &blk)
    end

    def push(*args)
      ensure_mapper
      @mapper.push(*args)
    end

    def ensure_mapper
      raise MapperNotRunning.new('A mapper needs to be started via Nanite.start_mapper') unless @mapper
    end
  end
end
