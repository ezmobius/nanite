#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/nanite'

# cli.rb
#
# You will need to have run the examples/rabbitconf.rb script at least one time before you
# run this so the expected users and vhosts are in place in RabbitMQ.
#
# You should also have started the 'simpleagent' nanite in a separate shell by running:
#
#  cd <NANITE>/examples/simpleagent
#  nanite
#
# This test script takes a little more than 16 seconds to run since we start a new
# mapper within, and pause while we wait for it to initialize, receive pings from
# available agents (which have a default ping time of 15 seconds), and register
# those agents and their methods.  When this process is presumed complete after
# 16 seconds we can finally send the nanite agent the task to execute.

EM.run do
  # start up a new mapper with a ping time of 15 seconds
  Nanite.start_mapper(:host => 'localhost', :user => 'mapper', :pass => 'testing', :vhost => '/nanite', :log_level => 'info')

  # have this run after 16 seconds so we can be pretty sure that the mapper
  # has already received pings from running nanites and registered them.
  EM.add_timer(16) do
    # call our /simple/echo nanite, and pass it a string to echo back
    Nanite.request("/simple/echo", "hello world!") do |res|
      p res
      EM.stop_event_loop
    end
  end
end

