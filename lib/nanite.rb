$:.unshift File.dirname(__FILE__)

module Nanite
  def self.checkout_dir
    "~/.nanite/repositories"
  end
   
  def self.configure &block
    (@@configuration ||= Configuration.new).instance_eval &block
  end
end

require 'nanite/specification'
require 'nanite/configuration'
require 'nanite/repository'