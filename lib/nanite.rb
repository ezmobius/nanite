require 'rubygems'
require 'amqp'
require 'mq'
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
require 'json'
require 'logger'


module Nanite

  VERSION = '0.1.0' unless defined?(Nanite::VERSION)

  def self.start(options)
    Agent.start(options)
  end

  def self.gensym
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
end

