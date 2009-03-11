require 'redis'

module Nanite
  class State
    
    include Enumerable
    
    def initialize
      @redis = Redis.new
    end
    
    def catch_redis_error(meth,&blk)
      blk.call
    rescue RedisError => e
      Nanite::Log.info("redis error in method: #{meth}")
      raise e
    end
    
    def [](nanite)
      catch_redis_error("[]") do
        status = @redis[nanite]
        timestamp = @redis["t-#{nanite}"]
        services = @redis.set_members("s-#{nanite}")
        return nil unless status && timestamp && services
        {:services => services, :status => status, :timestamp => timestamp.to_i}
      end
    end
    
    def []=(nanite, hsh)
      catch_redis_error("[]=") do
        update_state(nanite, hsh[:status], hsh[:services])
      end
    end
    
    def delete(nanite)
      catch_redis_error("delete") do
        redis.set_members("s-#{nanite}").each do |srv|
          @redis.set_delete(s, nanite)
        end
        @redis.delete nanite
        @redis.delete "s-#{nanite}"
        @redis.delete "t-#{nanite}"
      end
    end
    
    def all_services
      catch_redis_error("all_services") do
        @redis.set_members("nanite-services")
      end
    end
    
    def update_state(name, status, services)
      old_services = @redis.set_members("srv-#{name}")
      if old_services
        (old_services - services).each do |s|
          @redis.set_delete(s, name)
        end
      end
      @redis.delete("s-#{name}")
      services.each do |srv|
        @redis.set_add(srv, name)
        @redis.set_add("s-#{name}", srv)
      end
      @redis[name] = status
      @redis["t-#{name}"] = Time.now.to_i
    end
    
    def list_nanites
      catch_redis_error("list_nanites") do
        @redis.keys("nanite-*")
      end
    end
    
    def clear_state
      catch_redis_error("clear_state") do
        @redis.keys("*").each {|k| @redis.delete k}
      end
    end
    
    def each
      list_nanites.each do |nan|
        yield({:services => @redis["s-#{nan}"], :status => @redis[nan], :timestamp => @redis["t-#{nan}"]})
      end
    end
    
    def nanites_for(*srvs)
      catch_redis_error("nanites_for") do
        res = []
        @redis.set_intersect(srvs).each do |nan|
          res << [nan, self[nan]]
        end
        res
      end
    end
  end
end  