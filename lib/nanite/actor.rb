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
        @exposed.map {|meth| "/#{prefix}/#{meth}".squeeze('/')}
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
    end # InstanceMethods
    
  end # Actor
end # Nanite