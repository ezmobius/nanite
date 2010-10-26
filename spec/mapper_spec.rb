require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::Mapper do
  include SpecHelpers
  before(:each) do
    reset_broker
  end

  describe "Initializing" do
    before(:each) do
      @mapper = Nanite::Mapper.new({})
    end

    it "should set the identity" do
      @mapper.identity.should_not == nil
      @mapper.identity.should =~ /mapper-.*/
    end

    it "should set the identity to a custom identity" do
      @mapper = Nanite::Mapper.new({:identity => "bob"})
      @mapper.identity.should == "mapper-bob"
    end

    it "should set the file root" do
      @mapper.options[:file_root].should == File.expand_path("#{File.dirname(__FILE__)}/../files")
    end
  end

  describe "Starting" do
    include Nanite::Notifications::NotificationCenter
    before(:each) do
      @mapper = Nanite::Mapper.new({:log_level => :debug})
      @mapper.stub!(:setup_queues)
      @mapper.stub!(:start_amqp)
      @mapper.stub!(:setup_processors)
    end

    it "should initialize the logger" do
      run_in_em do
        @mapper.run
        Nanite::Log.logger.level.should == Logger::DEBUG
      end
    end

    it "should set the prefetch value" do
      amqp = mock('amqp')
      MQ.stub(:new).and_return(amqp)

      mapper = Nanite::Mapper.new(:prefetch => 11)
      mapper.stub!(:setup_queues)
      mapper.stub!(:setup_processors)
      amqp.should_receive(:prefetch).with(11)
      mapper.run
    end

    it "should register the callbacks" do
      clear_notifications
      register = lambda {|identity| }
      unregister = lambda {|identity| }
      timed_out = lambda {|identity| }
      mapper = Nanite::Mapper.new(:callbacks => {:register => register, :unregister => unregister, :timed_out => timed_out})
      mapper.stub!(:start_amqp)
      mapper.stub!(:setup_queues)
      mapper.stub!(:setup_processors)
      mapper.run

      notifications[:register].first.should == [mapper, register]
    end
  end

  describe "Sending requests" do
    include Nanite::Helpers::StateHelper

    before(:each) do
      setup_state
      reset_broker
      EM.stub(:add_periodic_timer).and_yield
      @request = Nanite::Request.new('/some/service', 'payload', nil, :token => 'token')
      @mapper = Nanite::Mapper.new(:identity => 'mapper')
      @mapper.run
    end

    after(:each) do
      reset_state
    end

    it "should set the reply_to to its identity" do
      @mapper.send_request(@request)
      @request.reply_to.should == "mapper-mapper"
    end

    it "should be false if the request couldn't be sent" do
      @mapper.send_request(@request).should == false
    end

    it "should push the message on the offline queue when enabled" do
      @mapper.options[:offline_failsafe] = true
      stored_offline = false
      MQ.queue('mapper-offline').subscribe {|message|
        @mapper.serializer.load(message).token.should == @request.token
        stored_offline = true
      }

      @mapper.send_request(@request)
      stored_offline.should == true
    end

    it "should send the request to the agent if available" do
      nanites['nanite-1234'] = {:services => ['/some/service'], :timestamp => Time.now.utc}
      message_sent = false
      MQ.queue('nanite-1234').subscribe {|message|
        @mapper.serializer.load(message).token.should == @request.token
        message_sent = true
      }
      @mapper.send_request(@request)
      message_sent.should == true
    end
  end
end
