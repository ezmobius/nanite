require File.dirname(__FILE__) + '/spec_helper'
require 'nanite'
require 'nanite/mapper'
require 'nanite/actor'
require 'json'

class Foo < Nanite::Actor

  expose :bar
  
  def bar(payload)
    ['hello', payload]
  end
  
end  

describe "Nanite::Dispatcher" do
  it "should register an actor" do
    Nanite::Dispatcher.register(Foo.new)
    Nanite::Dispatcher.actors.size.should == 1 
  end
  
  it "should dispatch a request" do
    req = Nanite::Request.new('/foo/bar', 'payload', 'from', '0xdeadbeef', 'reply_to')
    res = Nanite::Dispatcher.dispatch_request(req)
    res.should be_kind_of Nanite::Result
    res.token.should == req.token
  end
  
  it "should know about all services" do
    Nanite::Dispatcher.register(Foo.new)
    Nanite::Dispatcher.all_services.should == ['/foo/bar']
  end
end

