module Nanite
  class Configuration
    attr_accessor :repository_root
    
    def initialize
      @objects = { :file => {} }
    end
    
    def add_repository(value)
      Repository.new(value =~ %r!://! ? value : repository_root + value)
    end
    
    def file(reference, *args)
      @objects[:file][reference] ||=
        Specification::File.new(*args)
    end
  end
end