require 'rubygems'
require 'amqp'
require 'mq'
require 'json'
require 'logger'
require 'yaml'
require 'openssl'
require 'fileutils'

$:.unshift File.dirname(__FILE__)
require 'nanite/amqp'
require 'nanite/util'
require 'nanite/config'
require 'nanite/packets'
require 'nanite/identity'
require 'nanite/console'
require 'nanite/daemonize'
require 'nanite/pid_file'
require 'nanite/job'
require 'nanite/mapper'
require 'nanite/actor'
require 'nanite/actor_registry'
require 'nanite/streaming'
require 'nanite/nanite_dispatcher'
require 'nanite/agent'
require 'nanite/cluster'
require 'nanite/reaper'
require 'nanite/log'
require 'nanite/mapper_proxy'
require 'nanite/security_provider'
require 'nanite/security/cached_certificate_store_proxy'
require 'nanite/security/certificate'
require 'nanite/security/certificate_cache'
require 'nanite/security/distinguished_name'
require 'nanite/security/encrypted_document'
require 'nanite/security/rsa_key_pair'
require 'nanite/security/secure_serializer'
require 'nanite/security/signature'
require 'nanite/security/static_certificate_store'
require 'nanite/serializer'

module Nanite
  VERSION = '0.4.1.13' unless defined?(Nanite::VERSION)

  class MapperNotRunning < StandardError; end

  class << self
    attr_reader :mapper, :agent

    def start_agent(options = {})
      @agent = Nanite::Agent.start(options)
    end

    def start_mapper(options = {})
      @mapper = Nanite::Mapper.start(options)
    end

    def start_mapper_proxy(options = {})
      identity = options[:identity] || Nanite::Identity.generate
      @mapper = Nanite::MapperProxy.new(identity, options)
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
      @mapper ||= MapperProxy.instance
      unless @mapper
        raise MapperNotRunning.new('A mapper needs to be started via Nanite.start_mapper')
      end
    end
  end
end
