require 'rubygems'
require 'amqp'
require 'mq'
require 'json'
require 'logger'
require 'yaml'

$:.unshift File.dirname(__FILE__)
require 'nanite/amqp'
require 'extlib'
require 'nanite/config'
require 'nanite/packets'
require 'nanite/identity'
require 'nanite/console'
require 'nanite/daemonize'
require 'nanite/job'
require 'nanite/mapper'
require 'nanite/actor'
require 'nanite/streaming'
require 'nanite/dispatcher'
require 'nanite/agent'
require 'nanite/cluster'
require 'nanite/reaper'
require 'nanite/serializer'
require 'nanite/log'

module Nanite
  VERSION = '0.2.0' unless defined?(Nanite::VERSION)
end
