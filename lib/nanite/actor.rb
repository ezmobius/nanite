module Nanite
  class Actor
    class << self
      attr_reader :exposed

      def expose(*meths)
        @exposed ||= []
        meths.each do |meth|
          @exposed << meth
        end
      end

      def provides_for(prefix)
        sets = []
        exposed.each do |meth|
          sets << "/#{prefix}/#{meth}".squeeze('/')
        end
        sets
      end
    end
  end
end
