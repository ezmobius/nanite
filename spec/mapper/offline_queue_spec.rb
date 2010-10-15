require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'moqueue'
overload_amqp

module EventMachine
  def self.add_periodic_timer(timeout, &blk)
    blk.call
  end

  def self.next_tick(&blk)
    blk.call
  end
end

class Moqueue::MockQueue
  def recover
  end
end

describe Nanite::Mapper::OfflineQueue do
  include Nanite::Helpers::StateHelper

  before(:each) do
    reset_broker
    @offline = Nanite::Mapper::OfflineQueue.new(:agent_timeout => 14)
    @offline.run
    @mq = mock_queue("mapper-offline")
    @push = Nanite::Push.new('/agent/log', "message")
    @serializer = Nanite::Serializer.new('yaml')
    @message = @serializer.dump(@push)
    setup_state(nil)
    nanites["nanite-1234"] = {:services  => '/agent/log', :timestamp => Time.now.utc.to_i}
  end
  
  it "should consume messages off the offline queue" do
    @mq.publish(@message)
    @mq.should have_received(@message)
  end

  it "should ack messages when a target was found" do
    @mq.publish(@message)
    @mq.should have_ack_for(@message)
  end

  it "should not ack the message when no target was found" do
    reset_state
    @mq.publish(@message)
    @mq.should_not have_ack_for(@message)
  end

  it "should resend the message to the selected target" do
    message_resent = false
    mock_queue("nanite-1234").subscribe do |message|
      message = @serializer.load(message)
      message.payload.should == @push.payload
      message.target.should == "nanite-1234"
      message_resent = true
    end
    @mq.publish(@message)
    message_resent.should == true
  end

  it "should recover regularly based on the redelivery frequency" do
    reset_broker
    @mq = mock_queue("mapper-offline")
    @mq.should_receive(:recover)
    @offline = Nanite::Mapper::OfflineQueue.new(:agent_timeout => 14)
    @offline.run
  end
end
