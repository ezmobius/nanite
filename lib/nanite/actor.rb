module Nanite
  class Actor
    cattr_reader :exposed

    def self.default_prefix
      to_s.to_const_path
    end

    def self.expose(*meths)
      @exposed ||= []
      meths.each do |meth|
        @exposed << meth
      end
    end

    def self.provides_for(prefix)
      sets = []
      @exposed.each do |meth|
        sets << "/#{prefix}/#{meth}".squeeze('/')
      end
      sets
    end
  end
end