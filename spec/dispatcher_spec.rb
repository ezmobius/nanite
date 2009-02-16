require File.dirname(__FILE__) + '/spec_helper'
require 'nanite'

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
    log = mock('log', :info => nil)
    amq = mock('amq', :queue => mock('queue', :publish => nil))
    @registry = Nanite::ActorRegistry.new(log)
    @registry.register(Foo.new, nil)
    @dispatcher = Nanite::Dispatcher.new(amq, @registry, Nanite::Serializer.new(:marshal), '0xfunkymonkey', log)
  end

  it "should dispatch a request" do
    req = Nanite::Request.new('/foo/bar', 'you', :from => 'from', :token => '0xdeadbeef', :reply_to => 'reply_to')
    res = @dispatcher.dispatch(req)
    res.should(be_kind_of(Nanite::Result))
    res.token.should == req.token
    res.results.should == ['hello', 'you']
  end
  
  it "should dispatch a request for default action" do
    req = Nanite::Request.new('/foo/', 'you', :from => 'from', :token => '0xdeadbeef', :reply_to => 'reply_to')
    res = @dispatcher.dispatch(req)
    res.should(be_kind_of(Nanite::Result))
    res.token.should == req.token
    res.results.should == ['hello', 'you']
  end
  
  it "should handle custom prefixes" do
    @registry.register(Foo.new, 'umbongo')
    req = Nanite::Request.new('/umbongo/bar', 'you', :from => 'from', :token => '0xdeadbeef', :reply_to => 'reply_to')
    res = @dispatcher.dispatch(req)
    res.should(be_kind_of(Nanite::Result))
    res.token.should == req.token
    res.results.should == ['hello', 'you']
  end
end

