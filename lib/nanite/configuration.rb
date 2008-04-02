module Nanite
  class Configuration
    def initialize
      @objects = { :file => {} }
    end
    def file(reference, *args)
      @objects[:file][reference] ||=
        Specification::File.new(*args)
    end
  end
end