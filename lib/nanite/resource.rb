module Nanite

  class Resource

    attr_reader :res
    
    def self.parse_hostname(hostname)
      return false if hostname.nil?
      matchdata = hostname.match /([a-z]+)(\d+)-([a-z]+)(\d+)/
      return false if matchdata.nil? || matchdata.size != 5
      cluster_name = matchdata[1] + matchdata[2]
      
      resource_type = case matchdata[3]
      when 's'; "slice"
      when 'n'; "node"
      when 'gw'; "gateway"
      end
      resource_number = matchdata[4].to_i
      
      [new('/cluster/'+cluster_name), new("/#{resource_type}/#{resource_number}")]
    end
    
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



