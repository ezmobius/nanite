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
    @requests = Nanite::Mapper::Requests.new
    @requests.run
    @mq = mock_queue("request")
    @request = Nanite::Request.new('/agent/log', "message", nil, :to => "nanite-1234")
    @message = Nanite::Serializer.new('yaml').dump(@request)
    state['nanite-1234'] = {:services => '/agent/log', :timestamp => Time.now.utc.to_i}
    @agent_queue = MQ.queue("nanite-1234")
  end

  describe "Handling requests from agents" do
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
