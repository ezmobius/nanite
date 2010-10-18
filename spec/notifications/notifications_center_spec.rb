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
      trigger(:register)
      @listener.registered.should == true
    end

    it "should trigger global listeners too" do
      @global = Listener.new
      @global.notify(:all_events)
      trigger(:register)
      @global.global.should == true
    end

    it "should include the argument passed in" do
      trigger(:register, 'identity')
      @listener.registered.should == 'identity'
    end
  end
end
