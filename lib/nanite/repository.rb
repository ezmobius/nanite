module Nanite
  class Repository
    attr_accessor :location
    
    def initialize(where)
      self.location = where
    end
  end
end