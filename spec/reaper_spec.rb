require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::Reaper do
  include SpecHelpers
  
  describe "When initializing" do
    include Nanite::Notifications::NotificationCenter
    before(:each) do
      clear_notifications
    end

    it "should setup a default frequency" do
      EM.should_receive(:add_periodic_timer).with(2)
      Nanite::Reaper.new
    end
    
    it "should use the specified frequency" do
      EM.should_receive(:add_periodic_timer).with(5)
      Nanite::Reaper.new(5)
    end

    it "should register for appropriate events" do
      EM.stub!(:add_periodic_timer)
      reaper = Nanite::Reaper.new
      notifications[:register].first.should == [reaper, :register]
      notifications[:unregister].first.should == [reaper, :unregister]
      notifications[:ping].first.should == [reaper, :update_or_register]
    end

  end
  
  describe "When registering a timeout block" do
    it "should add the block to the timeouts list" do
      callback = lambda {}
      run_in_em do
        reaper = Nanite::Reaper.new(10)
        reaper.register('1234567890')
        reaper.timeouts['1234567890'][:seconds].should == 11
      end
    end
  end
  
  describe "When reaping" do
    include Nanite::Notifications::NotificationCenter
    before(:each) do
      clear_notifications
    end

    it "should remove timed-out agents" do
      run_in_em do
        reaper = Nanite::Reaper.new(-0.1)
        reaper.register('1234567890')
        reaper.timeouts.should_not == {}
        reaper.send :reap
        reaper.timeouts.should == {}
      end
    end
    
    it "should not remove the agent when not timed out" do
      run_in_em do
        reaper = Nanite::Reaper.new(1)
        reaper.register('1234567890')
        reaper.timeouts.should_not == {}
        reaper.send :reap
        reaper.timeouts.should_not == {}
      end
    end
    
    it "should run the callback when agent has timed out" do
      called = false
      callback = lambda {|identity, mapper| called = true; true }
      notify(callback, :on => :timeout)
      run_in_em do
        reaper = Nanite::Reaper.new(-0.1)
        reaper.register('1234567890')
        reaper.send :reap
        called.should == true
      end
    end
    
    it "should not remove the agent when the block returns false" do
      called = false
      callback = lambda {|identity, mapper| false }
      notify(callback, :on => :timeout)
      run_in_em do
        reaper = Nanite::Reaper.new(-0.1)
        reaper.register('1234567890')
        reaper.send :reap
        reaper.timeouts['1234567890'].should_not == nil
      end
    end

    it "should remove the agent when the block returns true" do
      run_in_em do
        reaper = Nanite::Reaper.new(-0.1)
        reaper.register('1234567890')
        reaper.send :reap
        reaper.timeouts['1234567890'].should == nil
      end
    end

  end
  
  describe "When updating" do
    it "should reset the timeout" do
      run_in_em do
        reaper = Nanite::Reaper.new
        reaper.register('1234567890')
        
        lambda do
          reaper.update_or_register('1234567890')
        end.should change {reaper.timeouts['1234567890'][:timestamp]}
      end
    end
    
    it "should autoregister the token if not present" do
      run_in_em do
        reaper = Nanite::Reaper.new
        
        reaper.timeouts['1234567890'].should == nil
        reaper.update_or_register('1234567890')
        reaper.timeouts['1234567890'].should_not == nil
      end
    end
  end
  
  describe "When unregistering" do
    it "should remove the token from the timeouts list" do
      run_in_em do
        reaper = Nanite::Reaper.new
        reaper.register('1234567890')
        reaper.timeouts['1234567890'].should_not == nil
        reaper.unregister('1234567890')
        reaper.timeouts['1234567890'].should == nil
      end
    end
  end
end
