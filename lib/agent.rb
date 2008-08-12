require 'rubygems'
require 'amqp'
require 'mq'
require File.dirname(__FILE__) + '/nanite'
require File.dirname(__FILE__) + '/resource'
require File.dirname(__FILE__) + '/result'
require File.dirname(__FILE__) + '/op'
require File.dirname(__FILE__) + '/actor'
require File.dirname(__FILE__) + '/dispatcher'


class GemRunner < Nanite::Actor
  provides '/gem'
  
  def list(filter)
    ::Gem.source_index.refresh!.search(filter).flatten.collect {|gemspec| "#{gemspec.name} #{gemspec.version}"}  
  end
end 

module Nanite
  class << self
    attr_accessor :default_resources
    
    def mapper
      Thread.current[:mapper] ||= MQ.new.rpc('mapper')
    end  
    
    def amq
      Thread.current[:mq] ||= MQ.new
    end
  end
end


def run_event_loop(threaded = true)
  runner = proc do
    EM.run {
      name, *resources = ARGV
      Nanite.identity  = name
      Nanite.default_resources = resources.map{|r| Nanite::Resource.new(r)}
      Nanite::Dispatcher.register(GemRunner.new) #unless name == 'client'
      Nanite.mapper.register name, Nanite::Dispatcher.all_resources do |r|
        puts r
      end  
      
      Nanite.amq.queue(Nanite.identity).subscribe{ |msg|
        Nanite::Dispatcher.handle(Marshal.load(msg))
      }
    }
  end
  if threaded
    Thread.new { runner.call }
  else
    runner.call
  end      
end  


def op(type, payload, *resources)
  op = Nanite::Op.new(type, payload, *resources)
  Nanite.mapper.route(op) do |tok|
    p tok
  end
end

if ARGV.first.strip == 'client'
  run_event_loop
  ARGV.clear
  running = true
  while running
    puts "nanite>"
    type, payload, *resources = gets.split(' ')
    if type == 'die'
      running = false 
      next
    end  
    op(type, payload, *resources)
  end  
else
  run_event_loop false
end  
