class MQ
  class Queue
    def recover
      @mq.callback{
        @mq.send Protocol::Basic::Recover.new({ :requeue => 0 })
      }
      self
    end
  end
end

# monkey patch to the amqp gem that adds :no_declare => true option for new 
# Exchange objects. This allows us to send messeages to exchanges that are
# declared by the mappers and that we have no configuration priviledges on.
# temporary uyntil we get this into amqp proper
MQ::Exchange.class_eval do
  def initialize mq, type, name, opts = {}
    @mq = mq
    @type, @name = type, name
    @mq.exchanges[@name = name] ||= self
    @key = opts[:key]
  
    @mq.callback{
      @mq.send AMQP::Protocol::Exchange::Declare.new({ :exchange => name,
                                                 :type => type,
                                                 :nowait => true }.merge(opts))
    } unless name == "amq.#{type}" or name == '' or opts[:no_declare]
  end
end

module Nanite
  module AMQPHelper
    def start_amqp(options)
      AMQP.start(:user => options[:user], :pass => options[:pass], :vhost => options[:vhost],
        :host => options[:host], :port => (options[:port] || ::AMQP::PORT).to_i)
      MQ.new
    end
  end
end

