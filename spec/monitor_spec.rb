require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::Agent::Monitor do
  include SpecHelpers
  before(:each) do
    @agent = stub(:agent, :unsubscribe => true, :un_register => true, :disconnect => true)
    @monitor = Nanite::Agent::Monitor.new(@agent)
    @monitor.stub!(:exit)
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
  
  describe "when initiating shutdown" do
    it "should unsubscribe and unregister the agent queues and system" do
      run_in_em do
        @agent.should_receive(:unsubscribe)
        @agent.should_receive(:un_register)
        @monitor.initiate_shutdown
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