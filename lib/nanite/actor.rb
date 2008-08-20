require 'nanite/resource'
module Nanite
  class Actor
    class << self      
      def provides(*resources)
        @provides ||= []
        resources.each do |res|
          @provides << Nanite::Resource.new(res)
        end
        @provides 
      end  
    end
      
    def provides
      self.class.provides
    end
  
    def to_s
      "<Actor[#{self.class.name}]: provides=#{provides.map{|n| n.to_s }.join(', ')}>"
    end
  
  end
end  