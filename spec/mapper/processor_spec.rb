require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Nanite::Mapper::Processor do
  
  before(:each) do
    reset_broker
    EM.stub!(:add_periodic_timer).and_yield
  end

  describe "When running" do
    let(:processor) {Nanite::Mapper::Processor.new}

    it "should start the heartbeat process" do
      processor.run
      processor.heartbeat.should_not == nil
      processor.heartbeat.running.should == true
    end

    it "should start the offline process" do
      processor.options[:offline_failsafe] = true
      processor.run
      processor.offline_queue.should_not == nil
      processor.offline_queue.running.should == true
    end

    it "should not start the offline process if offline support was disabled" do
      processor.options[:offline_failsafe] = nil
      processor.run
      processor.offline_queue.should == nil
    end

    it "should start the request process" do
      processor.run
      processor.requests.should_not == nil
      processor.requests.running.should == true
    end
  end
end
