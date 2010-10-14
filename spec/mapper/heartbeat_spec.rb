require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

require 'moqueue'

overload_amqp

describe Nanite::Mapper::Heartbeat do
  include Nanite::Helpers::StateHelper

  before(:each) do
    reset_broker
    @heartbeat = Nanite::Mapper::Heartbeat.new
    @heartbeat.run
    reset_state
    @mq = mock_queue("registration")
    @registration = Nanite::Register.new('nanite-1234', ['/agent/log'], '0.1', ['logging'])
    @serializer = Nanite::Serializer.new("yaml")
    @message = @serializer.dump(@registration)
  end

  describe "Handling registrations" do
    it "should add the agent to the list of nanites" do
      @heartbeat.handle_registration(@registration)
      nanites.should have(1).item
    end

    it "should store the services, tags and status" do
      @heartbeat.handle_registration(@registration)
      nanites['nanite-1234'][:status].should == '0.1'
      nanites['nanite-1234'][:tags].should == ['logging']
      nanites['nanite-1234'][:services].should == ['/agent/log']
    end

    it "should store a timestamp for the agent" do
      @heartbeat.handle_registration(@registration)
      nanites['nanite-1234'][:timestamp].should_not == nil
    end

    it "should ignore other packages" do


    end

    describe "with messages" do
      it "should register the agent" do
        @heartbeat.should_receive(:handle_registration)
        @mq.publish(@message) 
        @mq.should have_received(@message)
      end
    end
  end

  describe "Handling pings" do

  end
end
