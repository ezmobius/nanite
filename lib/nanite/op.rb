module Nanite
  class Op
    attr_accessor :from, :payload, :type, :token, :resources, :reply_to
    def initialize(type, payload, *resources)
      @type, @payload, @resources = type, payload, resources.map{|r| Nanite::Resource.new(r)}
      @from = Nanite.user
    end
  end
end  