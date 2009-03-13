require 'redis'

module Nanite
  class State
    include Enumerable
    
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
    # /gems/list: { nanite-foobar, nanite-nickelbag, nanite-another } # redis SET
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
      Nanite::Log.info("initializing redis state: #{redis}")
      host, port = redis.split(':')
      host ||= '127.0.0.1'
      port ||= '6379'
      @redis = Redis.new :host => host, :port => port
    end
    
    def log_redis_error(meth,&blk)
      blk.call
    rescue RedisError => e
      Nanite::Log.info("redis error in method: #{meth}")
      raise e
    end
    
    def [](nanite)
      log_redis_error("[]") do
        status = @redis[nanite]
        timestamp = @redis["t-#{nanite}"]
        services = @redis.set_members("s-#{nanite}")
        tags = @redis.set_members("tg-#{nanite}")
        return nil unless status && timestamp && services
        {:services => services, :status => status, :timestamp => timestamp.to_i, :tags => tags}
      end
    end
    
    def []=(nanite, hsh)
      log_redis_error("[]=") do
        update_state(nanite, hsh[:status], hsh[:services], hsh[:tags])
      end
    end
    
    def delete(nanite)
      log_redis_error("delete") do
        (@redis.set_members("s-#{nanite}")||[]).each do |srv|
          @redis.set_delete(srv, nanite)
          if @redis.set_count(srv) == 0
            @redis.delete(srv)
            @redis.set_delete("naniteservices", srv)
          end
        end
        (@redis.set_members("tg-#{nanite}")||[]).each do |tag|
          @redis.set_delete(tag, nanite)
          if @redis.set_count(tag) == 0
            @redis.delete(tag)
            @redis.set_delete("nanitetags", tag)
          end
        end
        @redis.delete nanite
        @redis.delete "s-#{nanite}"
        @redis.delete "t-#{nanite}"
        @redis.delete "tg-#{nanite}"
      end
    end
    
    def all_services
      log_redis_error("all_services") do
        @redis.set_members("naniteservices")
      end
    end

    def all_tags
      log_redis_error("all_tags") do
        @redis.set_members("nanitetags")
      end
    end
    
    def update_state(name, status, services, tags)
      old_services = @redis.set_members("s-#{name}")
      if old_services
        (old_services - services).each do |s|
          @redis.set_delete(s, name)
          @redis.set_delete("naniteservices", s)
        end
      end
      old_tags = @redis.set_members("tg-#{name}")
      if old_tags
        (old_tags - tags).each do |t|
          @redis.set_delete(t, name)
          @redis.set_delete("nanitetags", t)
        end
      end
      @redis.delete("s-#{name}")
      services.each do |srv|
        @redis.set_add(srv, name)
        @redis.set_add("s-#{name}", srv)
        @redis.set_add("naniteservices", srv)
      end
      @redis.delete("tg-#{name}")
      tags.each do |tag|
        @redis.set_add(tag, name)
        @redis.set_add("tg-#{name}", tag)
        @redis.set_add("nanitetags", tag)
      end
      @redis[name] = status
      @redis["t-#{name}"] = Time.now.to_i
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
        (@redis.set_intersect(keys)||[]).each do |nan|
          res << [nan, self[nan]]
        end
        res
      end
    end
  end
end  