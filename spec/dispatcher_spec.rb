require File.dirname(__FILE__) + '/spec_helper'
require 'nanite'
require 'nanite/mapper'
require 'nanite/actor'
require 'json'

class Foo < Nanite::Actor

  expose :bar, :index

  def index(payload)
    bar(payload)
  end
  
  def bar(payload)
    ['hello', payload]
  end
  
end  

describe "Nanite::Dispatcher" do
  before(:each) do
    @dispatcher = Nanite::Dispatcher.new(Nanite::Agent.new)
  end

  it "should not register anything except Nanite::Actor" do
    lambda{@dispatcher.register(String.new)}.should raise_error(ArgumentError)
  end  

  it "should register an actor" do
    @dispatcher = Nanite::Dispatcher.new(Nanite::Agent.new)
    @dispatcher.register(Foo.new)
    @dispatcher.actors.size.should == 1
  end
  
  it "should dispatch a request" do
    req = Nanite::Request.new('/foo/bar', 'payload', 'from', '0xdeadbeef', 'reply_to')
    res = @dispatcher.dispatch_request(req)
    res.should be_kind_of Nanite::Result
    res.token.should == req.token
  end
  
  it "should dispatch a request for default action" do
    req = Nanite::Request.new('/foo', 'payload', 'from', '0xdeadbeef', 'reply_to')
    res = @dispatcher.dispatch_request(req)
    res.should be_kind_of Nanite::Result
    res.token.should == req.token
  end

  it "should know about all services" do
    @dispatcher.register(Foo.new)
    @dispatcher.all_services.should == ['/foo/bar', '/foo/index']
  end
end

