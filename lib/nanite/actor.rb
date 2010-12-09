module Nanite
  # This mixin provides Nanite actor functionality.
  #
  # To use it simply include it your class containing the functionality to be exposed:
  #
  #   class Foo
  #     include Nanite::Actor
  #     expose :bar
  #
  #     def bar(payload)
  #       # ...
  #     end
  #
  #   end
  module Actor
    def self.running_jobs?
      @running_jobs and @running_jobs.any?
    end
    
    def self.add_running_job(message)
      @running_jobs ||= Set.new
      @running_jobs << message
    end
    
    def self.remove_running_job(message, retries = 0)
      @running_jobs ||= Set.new
      if @running_jobs.include?(message)
        @running_jobs.delete(message)
      elsif retries < 3
        EM.next_tick {remove_running_job(message, retries + 1)}
      end
    end
    
    def self.running_jobs
      @running_jobs
    end
    
    def self.included(base)
      base.class_eval do 
        include Nanite::Actor::InstanceMethods
        extend  Nanite::Actor::ClassMethods
      end # base.class_eval
    end # self.included
    
    module ClassMethods
      def default_prefix
        to_s.to_const_path
      end

      def expose(*meths)
        @exposed ||= []
        meths.each do |meth|
          @exposed << meth unless @exposed.include?(meth)
        end
      end

      def provides_for(prefix)
        return [] unless @exposed
        @exposed.select do |meth|
          if instance_methods.include?(meth.to_s) or instance_methods.include?(meth.to_sym)
            true
          else
            Nanite::Log.warn("Exposing non-existing method #{meth} in actor #{name}")
            false
          end
        end.map {|meth| "/#{prefix}/#{meth}".squeeze('/')}
      end

      def on_exception(proc = nil, &blk)
        raise 'No callback provided for on_exception' unless proc || blk
        @exception_callback = proc || blk
      end

      def exception_callback
        @exception_callback
      end
      
    end # ClassMethods     
    
    module InstanceMethods
      # send nanite request to another agent (through the mapper)
      def request(*args, &blk)
        MapperProxy.instance.request(*args, &blk)
      end
      
      def push(*args)
        MapperProxy.instance.push(*args)
      end
      
      def done(message)
        EM.next_tick do
          Nanite::Log.debug("Marking job as done")
          Nanite::Actor.remove_running_job(message)
        end
      end
    end # InstanceMethods
    
  end # Actor
end # Nanite