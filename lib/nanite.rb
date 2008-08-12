require 'rubygems'
require 'amqp'
require 'mq'
$:.unshift File.dirname(__FILE__)
require 'nanite/resource'
require 'nanite/result'
require 'nanite/op'
require 'nanite/answer'

module Nanite
  class << self
    attr_accessor :identity
    
    attr_accessor :default_resources
    
    def mapper
      Thread.current[:mapper] ||= MQ.new.rpc('mapper')
    end  
    
    def amq
      Thread.current[:mq] ||= MQ.new
    end
    
    def pending
      @pending ||= {}
    end
    
    def results
      @results ||= {}
    end
    
    def gen_token
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
    
    def queue(q)
      @queues ||= Hash.new { |h,k| h[k] = Queue.new }
      @queues[q]
    end
        
    def delete_queue(q)
      @queues.delete(q)
    end
  end  
end  