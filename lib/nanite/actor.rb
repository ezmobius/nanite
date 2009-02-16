module Nanite
  class Actor
    def self.default_prefix
      to_s.to_const_path
    end

    def self.expose(*meths)
      @exposed ||= []
      meths.each do |meth|
        @exposed << meth
      end
    end

    def self.provides_for(prefix)
      @exposed.map {|meth| "/#{prefix}/#{meth}".squeeze('/')}
    end
  end

  class ActorRegistry
    attr_reader :actors, :log

    def initialize(log)
      @log = log
      @actors = {}
    end

    def register(actor, prefix)
      raise ArgumentError, "#{actor.inspect} is not a Nanite::Actor subclass instance" unless Nanite::Actor === actor
      log.info("Registering #{actor.inspect} with prefix #{prefix.inspect}")
      prefix ||= actor.class.default_prefix
      actors[prefix.to_s] = actor
    end

    def services
      actors.map {|prefix, actor| actor.class.provides_for(prefix) }.flatten.uniq
    end

    def actor_for(prefix)
      actor = actors[prefix]
    end
  end
end