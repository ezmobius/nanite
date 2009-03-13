module Nanite
  class LocalState < ::Hash
    def initialize(hsh={})
      hsh.each do |k,v|
        self[k] = v
      end
    end
    
    def all_services
      map{|n,s| s[:services] }.flatten.uniq
    end

    def all_tags
      map{|n,s| s[:tags] }.flatten.uniq
    end
    
    def nanites_for(service, *tags)
      tags = tags.dup.flatten
      res = select { |name, state| state[:services].include?(service) }
      unless tags.empty?
        res.select {|a| 
          p(a[1][:tags] & tags)
          !(a[1][:tags] & tags).empty? 
        }
      else
        res
      end
    end
  end
end