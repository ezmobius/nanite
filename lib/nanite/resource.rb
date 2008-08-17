module Nanite

  class Resource

    attr_reader :res
    
    def eql?(other)
      self == other
    end
    
    def hash
      to_s.hash
    end
    
    def ==(other)
      @res == other.res
    end
    
    def <=(other)
      @res[0, other.res.size] == other.res
    end
    
    def >=(other)
      @res == other.res[0, @res.size]
    end
    
    def <(other)
      not @res >= other.res
    end
    
    def >(other)
      not @res <= other.res
    end
    
    def initialize(res)
      raise ArgumentError.new('resources *must* start with a /') unless res[0] == ?/
      @res = res[1..-1].split('/')
    end
    
    def to_s
      "/#{@res.join('/')}"
    end

  end
end



