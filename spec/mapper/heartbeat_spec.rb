require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

require 'moqueue'

overload_amqp

describe Nanite::Mapper::Heartbeat do
  include Nanite::Helpers::StateHelper

  before(:each) do
    reset_broker
    @heartbeat = Nanite::Mapper::Heartbeat.new(:identity => 'mapper', :agent_timeout => 15)
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

    it "should fire the register callback with the identity" do
      called_back = false
      block = lambda do |identity, mapper|
        identity.should == "nanite-1234"
        called_back = true
      end
      @heartbeat.callbacks[:register] = block

      @heartbeat.handle_registration(@registration)
      called_back.should == true
    end

    it "should ignore other packets" do
      lambda {
        nanites.should have(0).items
        @heartbeat.handle_registration(Nanite::Advertise.new)
        nanites.should have(0).items
      }.should_not raise_error
    end

    describe "with messages" do
      it "should register the agent" do
        @heartbeat.should_receive(:handle_registration)
        @mq.publish(@message) 
        @mq.should have_received(@message)
      end

      it "should fetch messages from a private queue when state isn't shared" do
        reset_broker
        @private = mock_queue("registration-mapper").bind(MQ.fanout('registration'))
        @heartbeat.stub!(:shared_state?).and_return(false)
        @heartbeat.run
        @private.publish(@message)
        @private.should have_received(@message)
      end
    end

    describe "when unregistering" do
      before(:each) do
        state['nanite-1234'] = {:services => '/agent/log'}
        @unregistration = Nanite::UnRegister.new('nanite-1234')
        @message = @serializer.dump(@unregistration)
      end

      it "should remove the agent from the state list" do
        @heartbeat.handle_registration(@unregistration)
        state['nanite-1234'].should == nil
      end

      it "should fire the unregister callback with the identity" do
        called_back = false
        block = lambda do |identity, mapper|
          identity.should == "nanite-1234"
          called_back = true
        end

        @heartbeat.callbacks[:unregister] = block
        @heartbeat.handle_registration(@unregistration)
        called_back.should == true
      end
    end
  end

  describe "Handling pings" do
    before(:each) do
      @ping = Nanite::Ping.new('nanite-1234', '0.3')
    end

    describe "when the nanite is not known" do
      it "should send an advertise request to the agent" do
        sent_advertise = false
        mock_queue('nanite-1234').subscribe do |message|
          @advertise = @serializer.load(message)
          @advertise.should be_instance_of(Nanite::Advertise)
          @advertise.target.should == "nanite-1234"
          sent_advertise = true
        end
        @heartbeat.handle_ping(@ping)
        sent_advertise.should == true
      end
    end

    describe "when the nanite is known" do
      before(:each) do
        state['nanite-1234'] = {:services => ["/agent/log"], :timestamp => 0, :status => "0.0"}
      end

      it "should update the timestamp" do
        @heartbeat.handle_ping(@ping)
        state['nanite-1234'][:timestamp].should > 0
      end

      it "should update the status" do
        @heartbeat.handle_ping(@ping)
        state["nanite-1234"][:status].should == "0.3"
      end
    end

  end

  describe "Handling time outs" do
    before(:each) do
      nanites["nanite-1234"] = {:timestamp => 0}
    end

    it "should remove the nanite if it's timed out" do
      @heartbeat.nanite_timed_out("nanite-1234")
      nanites["nanite-1234"].should == nil
    end

    it "should not remove the nanite if the timestamp has been updated already" do
      nanites["nanite-1234"][:timestamp] = Time.now.utc.to_i
      @heartbeat.nanite_timed_out("nanite-1234")
      nanites["nanite-1234"].should_not == nil
    end
    
    it "shouldn't fail it the nanite can't be found" do
      lambda {
        @heartbeat.nanite_timed_out("nanite-1111")
      }.should_not raise_error
    end

    it "should fire the timeout callback if set" do
      called_back = false
      @heartbeat.callbacks[:timeout] = lambda{|identity, mapper|
        identity.should == "nanite-1234"
        called_back = true
      }
      @heartbeat.nanite_timed_out("nanite-1234")
      called_back.should == true
    end

    it "should return true when the nanite was removed" do
      @heartbeat.nanite_timed_out("nanite-1234").should == true
    end

    it "should return nil when the nanite wasn't removed" do
      nanites["nanite-1234"][:timestamp] = Time.now.utc.to_i
      @heartbeat.nanite_timed_out("nanite-1234").should == nil
    end
  end
end
