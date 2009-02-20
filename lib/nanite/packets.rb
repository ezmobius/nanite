module Nanite
  # Base class for all Nanite packets,
  # knows how to dump itself to JSON
  class Packet
    def initialize
      raise NotImplementedError.new("#{self.class.name} is an abstract class.")
    end
    def to_json(*a)
      {
        'json_class'   => self.class.name,
        'data'         => instance_variables.inject({}) {|m,ivar| m[ivar.sub(/@/,'')] = instance_variable_get(ivar); m }
      }.to_json(*a)
    end
  end

  # packet that means start of a file transfer
  # operation
  class FileStart < Packet
    attr_accessor :filename, :token, :dest
    def initialize(filename, dest, token)
      @filename = filename
      @dest = dest
      @token = token
    end

    def self.json_create(o)
      i = o['data']
      new(i['filename'], i['dest'], i['token'])
    end
  end

  # packet that means end of a file transfer
  # operation
  class FileEnd < Packet
    attr_accessor :token, :meta
    def initialize(token, meta)
      @token = token
      @meta  = meta
    end

    def self.json_create(o)
      i = o['data']
      new(i['token'], i['meta'])
    end
  end

  # packet that carries data chunks during a file transfer
  class FileChunk < Packet
    attr_accessor :chunk, :token
    def initialize(token, chunk=nil)
      @chunk = chunk
      @token = token
    end
    def self.json_create(o)
      i = o['data']
      new(i['token'], i['chunk'])
    end
  end

  # packet that means a work request from mapper
  # to actor node
  #
  # type     is a service name
  # payload  is arbitrary data that is transferred from mapper to actor
  #
  # Options:
  # from     is sender identity
  # token    is a generated request id that mapper uses to identify replies
  # reply_to is identity of the node actor replies to, usually a mapper itself
  # selector is the selector used to route the request
  # target   is the target nanite for the request
  # persistent signifies if this request should be saved to persistent storage by the AMQP broker
  class Request < Packet
    attr_accessor :from, :payload, :type, :token, :reply_to, :selector, :target, :persistent
    DEFAULT_OPTIONS = {:selector => :least_loaded}
    def initialize(type, payload, opts={})
      opts = DEFAULT_OPTIONS.merge(opts)
      @type             = type
      @payload          = payload
      @from             = opts[:from]
      @token            = opts[:token]
      @reply_to         = opts[:reply_to]
      @selector         = opts[:selector]
      @target           = opts[:target]
      @persistent       = opts[:persistent]
    end
    def self.json_create(o)
      i = o['data']
      new(i['type'], i['payload'], {:from => i['from'], :token => i['token'], :reply_to => i['reply_to'], :selector => i['selector'],
        :target => i['target'], :persistent => i['persistent']})
    end
  end

  # packet that means a work push from mapper
  # to actor node
  #
  # type     is a service name
  # payload  is arbitrary data that is transferred from mapper to actor
  #
  # Options:
  # from     is sender identity
  # token    is a generated request id that mapper uses to identify replies
  # selector is the selector used to route the request
  # target   is the target nanite for the request
  # persistent signifies if this request should be saved to persistent storage by the AMQP broker
  class Push < Packet
    attr_accessor :from, :payload, :type, :token, :selector, :target, :persistent
    DEFAULT_OPTIONS = {:selector => :least_loaded}
    def initialize(type, payload, opts={})
      opts = DEFAULT_OPTIONS.merge(opts)
      @type             = type
      @payload          = payload
      @from             = opts[:from]
      @token            = opts[:token]
      @selector         = opts[:selector]
      @target           = opts[:target]
      @persistent       = opts[:persistent]
    end
    def self.json_create(o)
      i = o['data']
      new(i['type'], i['payload'], {:from => i['from'], :token => i['token'], :selector => i['selector'],
        :target => i['target'], :persistent => i['persistent']})
    end
  end

  # packet that means a work result notification sent from actor to mapper
  #
  # from     is sender identity
  # results  is arbitrary data that is transferred from actor, a result of actor's work
  # token    is a generated request id that mapper uses to identify replies
  # to       is identity of the node result should be delivered to
  class Result < Packet
    attr_accessor :token, :results, :to, :from
    def initialize(token, to, results, from)
      @token = token
      @to = to
      @from = from
      @results = results
    end
    def self.json_create(o)
      i = o['data']
      new(i['token'], i['to'], i['results'], i['from'])
    end
  end

  # packet that means an availability notification sent from actor to mapper
  #
  # from     is sender identity
  # services is a list of services provided by the node
  # status   is a load of the node by default, but may be any criteria
  #          agent may use to report it's availability, load, etc
  class Register < Packet
    attr_accessor :identity, :services, :status
    def initialize(identity, services, status)
      @status = status
      @identity = identity
      @services = services
    end
    def self.json_create(o)
      i = o['data']
      new(i['identity'], i['services'], i['status'])
    end
  end

  # heartbeat packet
  #
  # identity is sender's identity
  # status   is sender's status (see Register packet documentation)
  class Ping < Packet
    attr_accessor :identity, :status
    def initialize(identity, status)
      @status = status
      @identity = identity
    end
    def self.json_create(o)
      i = o['data']
      new(i['identity'], i['status'])
    end
  end

  # packet that is sent by workers to the mapper
  # when worker initially comes online to advertise
  # it's services
  class Advertise < Packet
    def initialize
    end
    def self.json_create(o)
      new
    end
  end
end

