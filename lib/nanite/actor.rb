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
      
    def advertise(*resources)
      self.class.provides(*resources)
      Nanite.advertise_resources
    end
    
    def provides
      self.class.provides
    end
    
    def revoke(*resources)
      resources.each do |res|
        self.class.provides.reject! {|p| Nanite::Resource.new(res) >= p }
      end
      Nanite.advertise_resources if resources.size > 0
    end
      
    def to_s
      "<Actor[#{self.class.name}]: provides=#{provides.map{|n| n.to_s }.join(', ')}>"
    end
  
  end
end  