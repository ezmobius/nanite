class MQ
  class Queue
    # Asks the broker to redeliver all unacknowledged messages on a
    # specifieid channel. Zero or more messages may be redelivered.
    #
    # * requeue (default false)
    # If this parameter is false, the message will be redelivered to the original recipient.
    # If this flag is true, the server will attempt to requeue the message, potentially then
    # delivering it to an alternative subscriber.
    #
    def recover requeue = false
      @mq.callback{
        @mq.send Protocol::Basic::Recover.new({ :requeue => requeue })
      }
      self
    end
  end
end

# monkey patch to the amqp gem that adds :no_declare => true option for new 
# Exchange objects. This allows us to send messeages to exchanges that are
# declared by the mappers and that we have no configuration priviledges on.
# temporary until we get this into amqp proper
MQ::Exchange.class_eval do
  def initialize mq, type, name, opts = {}
    @mq = mq
    @type, @name, @opts = type, name, opts
    @mq.exchanges[@name = name] ||= self
    @key = opts[:key]

    @mq.callback{
      @mq.send AMQP::Protocol::Exchange::Declare.new({ :exchange => name,
                                                 :type => type,
                                                 :nowait => true }.merge(opts))
    } unless name == "amq.#{type}" or name == ''  or opts[:no_declare]
  end
end

module Nanite
  module AMQPHelper
    def start_amqp(options)
      connection = AMQP.connect(:user => options[:user], :pass => options[:pass], :vhost => options[:vhost],
        :host => options[:host], :port => (options[:port] || ::AMQP::PORT).to_i, :insist => options[:insist] || false)
      MQ.new(connection)
    end
  end
end