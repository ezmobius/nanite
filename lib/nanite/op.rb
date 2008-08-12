module Nanite
  class Op
    attr_accessor :from, :payload, :type, :token, :resources
    def initialize(type, payload, *resources)
      @type, @payload, @resources = type, payload, resources.map{|r| Nanite::Resource.new(r)}
      @from = Nanite.identity
    end
  end
end  