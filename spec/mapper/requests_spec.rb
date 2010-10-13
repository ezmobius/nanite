require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

require 'moqueue'

overload_amqp

module EM
  def self.next_tick(&blk)
    blk.call
  end
end

describe Nanite::Mapper::Requests do
  include Nanite::Helpers::StateHelper

  before(:each) do
    reset_broker
    @requests = Nanite::Mapper::Requests.new(:identity => 'mapper', :log_level => 'warn')
    @requests.run
    @mq = mock_queue("request")
    @request = Nanite::Request.new('/agent/log', "message", nil, :to => "nanite-1234")
    @message = Nanite::Serializer.new('yaml').dump(@request)
    state['nanite-1234'] = {:services => '/agent/log', :timestamp => Time.now.utc.to_i}
    @agent_queue = MQ.queue("nanite-1234")
  end

  describe "Handling requests from agents" do
    describe "with messages" do
      it "should receive the message" do
        @mq.publish(@message)
        @mq.should have_received(@message)
      end

      it "should not raise an error if an error happened when handling the request" do
        @requests.stub!(:handle_request).and_raise(Exception.new)
        lambda {
          @mq.publish(@message)
        }.should_not raise_error
      end
    end

    describe "with local state" do
      before(:each) do
        reset_broker
        @requests = Nanite::Mapper::Requests.new(:identity => 'mapper')
        @requests.stub!(:shared_state?).and_return(false)
        @requests.run
        @mq = MQ.queue("request-mapper").bind(MQ.fanout("request"))
      end

      it "should receive messages from a private queue" do
        @mq.publish(@message)
        @mq.should have_received(@message)
      end
    end
  end

  describe "Handling pushes from agents" do
    describe "with messages" do
      before(:each) do
        @push = Nanite::Push.new("/agent/log", "message", nil, :to => "nanite-1234")
        @message = Nanite::Serializer.new('yaml').dump(@push)
      end

      it "should receive the message" do
        @mq.publish(@message)
        @mq.should have_received(@message)
      end

      it "should not raise an error if an error happened when handling the request" do
        @requests.stub!(:handle_request).and_raise(Exception.new)
        lambda {
          @mq.publish(@message)
        }.should_not raise_error
      end

    end
  end
end
