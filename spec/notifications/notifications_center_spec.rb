require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'nanite/notifications/notification_center'

describe Nanite::Notifications::NotificationCenter do
  describe "Subscribing to notifications" do
    include Nanite::Notifications::NotificationCenter
    before(:each) do
      clear_notifications
    end

    it "should add the listener to the list of notifications" do
      notify(:notify, :on => :register)
      notifications[:register].first.should == [self, :notify]
    end

    it "should add the listener to the list of global notifications" do
      notify(:notify)
      notifications[:_all].first.should == [self, :notify]
    end
  end

  describe "Being notified of events" do
    include Nanite::Notifications::NotificationCenter

    class Listener
      include Nanite::Notifications::NotificationCenter
      attr_reader :registered, :global
      def register(arg)
        @registered = (arg || true)
      end

      def all_events(arg)
        @global = (arg || true)
      end
    end

    before(:each) do
      clear_notifications
      @listener = Listener.new
      @listener.notify(:register, :on => :register)
    end

    it "should notify listeners of the triggered event" do
      trigger(:register, true)
      @listener.registered.should == true
    end

    it "should trigger global listeners too" do
      @global = Listener.new
      @global.notify(:all_events)
      trigger(:register, true)
      @global.global.should == true
    end

    it "should include the argument passed in" do
      trigger(:register, 'identity')
      @listener.registered.should == 'identity'
    end

    describe "using blocks" do
      before(:each) do
        clear_notifications
      end

      it "should trigger a registered callback" do
        triggered = false
        blk = lambda{|arg| triggered = arg }
        notify(blk, :on => :register)
        trigger(:register, 'nanite-1234')
        triggered.should == 'nanite-1234'
      end

      it "should trigger a block with two arguments (legacy)" do
        triggered = false
        blk = lambda{|identity, mapper| triggered = mapper }
        notify(blk, :on => :register)
        lambda {
          begin
            trigger(:register, 'nanite-1234', nil)
          rescue
            raise
          end
        }.should_not raise_error
        triggered.should == nil
      end
    end

    describe "when collecting results" do
      it "should return false if one callback was false" do
        false_block = lambda {|identity| false}
        true_block = lambda {|identity| true}
        notify(false_block, :on => :register)
        notify(true_block, :on => :register)
        trigger(:register, "nanite-1234").should == false
      end

      it "should return true if all callbacks returned true" do
        false_block = lambda {|identity| false}
        true_block = lambda {|identity| true}
        notify(false_block, :on => :register)
        notify(true_block, :on => :register)
        trigger(:register, "nanite-1234").should == false
      end

    end
  end
end
