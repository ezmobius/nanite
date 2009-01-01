#!/usr/bin/env ruby

require 'rubygems'
require 'nanite'
require 'nanite/mapper'

Nanite.identity = Nanite.gensym

EM.run {
  AMQP.start(:host => 'localhost', :user => 'mapper', :pass => 'testing', :vhost => '/nanite')
  Nanite.mapper = Nanite::Mapper.new(15)
  EM.add_timer(16) do
    Nanite.request("/simple/hello", '') do |res|
      p res
      EM.stop_event_loop
    end
  end
}

