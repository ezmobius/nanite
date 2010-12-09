require 'redis'

module Nanite
  class State
    include Enumerable
    
    attr_reader :redis

    # this class encapsulates the state of a nanite system using redis as the 
    # data store. here is the schema, for each agent we store a number of items,
    # for a nanite with the identity:  nanite-foobar we store the following things:
    #
    # nanite-foobar: 0.72 # load average or 'status'
    # s-nanite-foobar: { /foo/bar, /foo/nik } # a SET of the provided services
    # tg-nanite-foobar: { foo-42, customer-12 } # a SET of the tags for this agent
    # t-nanite-foobar: 123456789 # unix timestamp of the last state update
    #
    # also we do an inverted index for quick lookup of agents providing a certain
    # service, so for each service the agent provides, we add the nanite to a SET 
    # of all the nanites that provide said service:
    #
    # foo/bar: { nanite-foobar, nanite-nickelbag, nanite-another } # redis SET
    #
    # we do that same thing for tags:
    # some-tag: { nanite-foobar, nanite-nickelbag, nanite-another } # redis SET
    #
    # This way we can do a lookup of what nanites provide a set of services and tags based
    # on redis SET intersection:
    #
    # nanites_for('/gems/list', 'some-tag')
    # => returns a nested array of nanites and their state that provide the intersection
    # of these two service tags
    
    def initialize(redis)
      Nanite::Log.info("[setup] initializing redis state: #{redis}")
      @redis = Redis.new(redis_options(redis))
    end
    
    def redis_options(redis)
      case redis
      when String
        host, port = redis.split(':')
        host ||= '127.0.0.1'
        port ||= '6379'
        {:host => host, :port => port}
      when Hash
        redis
      end
    end

    def log_redis_error(meth,&blk)
      blk.call
    rescue Exception => e
      Nanite::Log.info("redis error in method: #{meth}")
      raise e
    end
    
    def [](nanite)
      log_redis_error("[]") do
        status = @redis[nanite]
        timestamp = @redis["t-#{nanite}"]
        services = @redis.smembers("s-#{nanite}")
        tags = @redis.smembers("tg-#{nanite}")
        return nil unless status && timestamp && services
        {:services => services, :status => status, :timestamp => timestamp.to_i, :tags => tags}
      end
    end
    
    def []=(nanite, attributes)
      log_redis_error("[]=") do
        update_state(nanite, attributes[:status], attributes[:services], attributes[:tags])
      end
    end
    
    def delete(nanite)
      log_redis_error("delete") do
        (@redis.smembers("s-#{nanite}")||[]).each do |srv|
          @redis.srem(srv, nanite)
          if @redis.scard(srv) == 0
            @redis.del(srv)
            @redis.srem("naniteservices", srv)
          end
        end
        (@redis.smembers("tg-#{nanite}")||[]).each do |tag|
          @redis.srem(tag, nanite)
          if @redis.scard(tag) == 0
            @redis.del(tag)
            @redis.srem("nanitetags", tag)
          end
        end
        @redis.del nanite
        @redis.del "s-#{nanite}"
        @redis.del "t-#{nanite}"
        @redis.del "tg-#{nanite}"
      end
    end
    
    def all_services
      log_redis_error("all_services") do
        @redis.smembers("naniteservices")
      end
    end

    def all_tags
      log_redis_error("all_tags") do
        @redis.smembers("nanitetags")
      end
    end
    
    def update_state(name, status, services, tags)
      old_services = @redis.smembers("s-#{name}")
      if old_services
        (old_services - services).each do |s|
          @redis.srem(s, name)
          @redis.srem("naniteservices", s)
        end
      end
      old_tags = @redis.smembers("tg-#{name}")
      if old_tags
        (old_tags - tags).each do |t|
          @redis.srem(t, name)
          @redis.srem("nanitetags", t)
        end
      end
      @redis.del("s-#{name}")
      services.each do |srv|
        @redis.sadd(srv, name)
        @redis.sadd("s-#{name}", srv)
        @redis.sadd("naniteservices", srv)
      end
      @redis.del("tg-#{name}")
      tags.each do |tag|
        next if tag.nil?
        @redis.sadd(tag, name)
        @redis.sadd("tg-#{name}", tag)
        @redis.sadd("nanitetags", tag)
      end
      update_status(name, status)
    end

    def update_status(name, status)
      @redis[name] = status
      @redis["t-#{name}"] = Time.now.utc.to_i
    end
    
    def list_nanites
      log_redis_error("list_nanites") do
        @redis.keys("nanite-*")
      end
    end
    
    def size
      list_nanites.size
    end
    
    def clear_state
      log_redis_error("clear_state") do
        @redis.keys("*").each {|k| @redis.delete k}
      end
    end
    
    def each
      list_nanites.each do |nan|
        yield nan, self[nan]
      end
    end
    
    def nanites_for(service, *tags)
      keys = tags.dup << service
      log_redis_error("nanites_for") do
        res = []
        (@redis.sinter(keys)||[]).each do |nan|
          res << [nan, self[nan]]
        end
        res
      end
    end
  end
end  
