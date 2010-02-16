require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::Agent::Monitor do
  include SpecHelpers
  
  module Nanite::DaemonizeHelper
    def daemonize(identity, options = {})
    end
  end
  
  before(:each) do
    @agent = stub(:agent, :unsubscribe => true, :un_register => true, :disconnect => true, :identity => 'identity', :pid_file => "pid")
    @monitor = Nanite::Agent::Monitor.new(@agent)
    @monitor.stub!(:exit)
  end

  after(:each) do
    Nanite::PidFile.new('identity', {}).remove
  end
  
  describe "When setting up the pid file" do
    after(:each) do
      Nanite::PidFile.new('identity', {}).remove
    end
    
    it "should set write a pid file when daemonize was requested" do
      @monitor = Nanite::Agent::Monitor.new(@agent, :daemonize => true)
      @monitor.stub!(:exit)
      Nanite::PidFile.new('identity', {}).exists?.should == true
    end
    
    it "should raise an error if a pid file exists" do
      Nanite::PidFile.new('identity', {}).write
      lambda {
        @monitor.setup_pid_file
      }.should raise_error
    end
  end
  
  describe "When gracefully shutting down" do
    before(:each) do
      EM.stub!(:add_timer).and_yield
      EM.stub!(:stop)
    end
    
    it "should mark itself as shutting_down" do
      @monitor.graceful_shutdown
      @monitor.shutting_down.should == true
    end
    
    it "should exit if called twice" do
      @monitor.graceful_shutdown
      @monitor.should_receive(:exit).and_throw :exit
      @monitor.should_not_receive(:initiate_shutdown)
      lambda {
        @monitor.graceful_shutdown
      }.should throw_symbol(:exit)
    end
    
    it "should exit when an error was raised when initiating shutdown" do
      @monitor.should_receive(:initiate_shutdown).and_raise RuntimeError.new
      Nanite::Log.should_receive(:error)
      @monitor.should_receive(:exit)
      @monitor.graceful_shutdown
    end
  end
  
  describe "When initiating shutdown" do
    it "should unsubscribe and unregister the agent queues and system" do
      run_in_em do
        @agent.should_receive(:unsubscribe)
        @agent.should_receive(:un_register)
        @monitor.initiate_shutdown
      end
    end
    
    it "should remove the pid file when daemonized" do
      run_in_em do
        @monitor = Nanite::Agent::Monitor.new(@agent, :daemonize => true)
        @monitor.stub!(:exit)
        @monitor.initiate_shutdown
        Nanite::PidFile.new('identity', {}).exists?.should == false
      end
    end
    
    it "should not remove a pid file when not daemonized" do
      run_in_em do
        @monitor.stub!(:exit)
        pidfile = Nanite::PidFile.new('identity', {})
        pidfile.write
        @monitor.initiate_shutdown
        pidfile.exists?.should == true
      end
    end
    
    describe "with graceful shutdown enabled" do
      before(:each) do
        @monitor.options[:graceful] = true
      end
      
      it "should wait for running agents" do
        Nanite::Actor.should_receive(:running_jobs?).and_return(true, false)
        run_in_em(false) do
          @monitor.initiate_shutdown
          EM.add_timer(1) do
            EM.stop
          end
        end
      end
      
      it "should disconnect the agent" do
        Nanite::Actor.stub!(:running_jobs?).and_return(true, false)
        run_in_em(false) do
          @agent.should_receive(:disconnect)
          @monitor.initiate_shutdown
          EM.add_timer(1) do
            EM.stop
          end
        end
      end
    end
  end
end