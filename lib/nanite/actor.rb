module Nanite
  class Actor
    class << self    
      attr_accessor :exposed
      def expose(*meths)
        @exposed ||= []
        meths.each do |meth|
          @exposed << meth
        end
      end  
    end
        
    def provides
      sets = []
      self.class.exposed.each do |meth|
        sets << "/#{self.class.to_s.downcase}/#{meth}"
      end  
      sets
    end
  end
end   