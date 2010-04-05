#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/nanite'

# cli.rb
#
# You will need to have run the examples/rabbitconf.rb script at least one time before you
# run this so the expected users and vhosts are in place in RabbitMQ.
#
# You should have started the 'secure' nanite in another shell by running:
#  cd <NANITE>/examples/secure-agent
#  nanite-agent --token encrypter
#
# This test script takes a little more than 16 seconds to run since we start a new
# mapper within, and pause while we wait for it to initialize, receive pings from
# available agents (which have a default ping time of 15 seconds), and register those 
# agents and their methods.  When this process is presumed complete after 16 seconds
# we can finally send the nanite agent the task to execute.

# Configure secure serializer
certs_dir = File.join(File.dirname(__FILE__), 'certs')
agent_cert = Nanite::Certificate.load(File.join(certs_dir, 'agent_cert.pem'))
store = Nanite::StaticCertificateStore.new(agent_cert, agent_cert)
mapper_cert = Nanite::Certificate.load(File.join(certs_dir, 'mapper_cert.pem'))
mapper_key = Nanite::RsaKeyPair.load(File.join(certs_dir, 'mapper_key.pem'))
Nanite::SecureSerializer.init("mapper", mapper_cert, mapper_key, store)


# Monkey patch secure serializer for the purpose of the example
module Nanite
  class SecureSerializer
    class << self
      alias :orig_dump :dump
      def dump(obj)
        puts "Serializing #{obj}..."
        res = orig_dump(obj)
        puts res
        puts "-----------------------\n\n"
        res
      end
      alias :orig_load :load
      def load(json)
        puts "Loading #{json}..."
        res = orig_load(json)
        puts res
        puts "-----------------------\n\n"
        res
      end
    end
  end
end

EM.run do
  # start up a new mapper
  Nanite.start_mapper(:format => :secure, :host => 'localhost', :user => 'mapper', :pass => 'testing', :vhost => '/nanite', :log_level => 'debug')

  EM.add_timer(16) do
    puts "Sending request..."
    Nanite.request("/secure/echo", "hello secure world!") do |res|
      p res
      EM.stop_event_loop
      puts "Done."
    end
  end
end

