$:.unshift File.dirname(__FILE__)

module Nanite
  def self.checkout_dir
    "~/.nanite/repositories"
  end
   
  def self.configure
    yield @@configuration ||= Configuration.new
  end
end

require 'nanite/specification'
require 'nanite/configuration'
require 'nanite/repository'