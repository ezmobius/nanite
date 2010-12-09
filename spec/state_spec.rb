require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'nanite/state'

describe ::Nanite::State do
  
  class ::Redis
    attr_accessor :options

    def initialize(options)
      @options = options
    end
  end

  context "Setting up Redis" do
    it "should accept a string with just a host name" do
      state = Nanite::State.new("localhost:6380")
      state.redis.options[:host].should == 'localhost'
      state.redis.options[:port].should == '6380'
    end

    it "should default to 127.0.0.1 and port 6379" do
      state = Nanite::State.new('')
      state.redis.options[:host].should == '127.0.0.1'
      state.redis.options[:port].should == '6379'
    end

    it "should accept a hash of options to pass to Redis" do
      state = Nanite::State.new(:host => 'localhost', :port => '6380', :timeout => 10)
      state.redis.options[:host].should == 'localhost'
      state.redis.options[:port].should == '6380'
      state.redis.options[:timeout].should == 10
    end
  end
end
