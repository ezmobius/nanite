module Nanite

  class Packet
    def to_json(*a)
      {
        'json_class'   => self.class.name,
        'data'         => instance_variables.inject({}) {|m,ivar| m[ivar.sub(/@/,'')] = instance_variable_get(ivar); m }

      }.to_json(*a)
    end
  end

  class FileStart < Packet
    attr_accessor :filename, :token, :dest
    def initialize(filename, dest, token=Nanite.gensym)
      @filename = filename
      @dest = dest
      @token = token
    end

    def self.json_create(o)
      i = o['data']
      new(i['filename'], i['dest'], i['token'])
    end
  end

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

  class Request < Packet
    attr_accessor :from, :payload, :type, :token, :reply_to
    def initialize(type, payload, from=Nanite.identity, token=nil, reply_to=nil)
      @type     = type
      @payload  = payload
      @from     = from
      @token    = token
      @reply_to = reply_to
    end
    def self.json_create(o)
      i = o['data']
      new(i['type'], i['payload'], i['from'], i['token'], i['reply_to'])
    end
  end

  class Result < Packet
    attr_accessor :token, :results, :to, :from
    def initialize(token, to, results, from=Nanite.identity)
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

  class Ping < Packet
    attr_accessor :identity, :status, :from
    def initialize(identity, status, from=Nanite.identity)
      @status = status
      @from = from
      @identity = identity
    end
    def self.json_create(o)
      i = o['data']
      new(i['identity'], i['status'], i['from'])
    end

  end

  class Pong < Packet
    attr_reader :token
    def self.json_create(o)
      new
    end
  end

  class Advertise < Packet
    attr_reader :token
    def self.json_create(o)
      new
    end
  end

end

