require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::Cluster do

  include SpecHelpers
  
  describe "Intialization" do

    before(:each) do
      @fanout = mock("fanout")
      @binding = mock("binding", :subscribe => true)
      @queue = mock("queue", :bind => @binding)
      @amq = mock("AMQueue", :queue => @queue, :fanout => @fanout)
      @serializer = mock("Serializer")
      @reaper = mock("Reaper")
      @mapper = mock("Mapper")
      Nanite::Reaper.stub!(:new).and_return(@reaper)
    end

    describe "State" do
      begin
        require 'nanite/state'
      rescue LoadError
      end

      if defined?(Redis)
        it "should use a local state by default" do
          cluster = Nanite::Cluster.new(@amq, 443, "the_identity", @serializer, @mapper)
          cluster.nanites.instance_of?(Nanite::LocalState).should == true
        end
      
        it "should set up a redis state when requested" do
          state = Nanite::State.new("")
          Nanite::State.should_receive(:new).with("localhost:1234").and_return(state)
          cluster = Nanite::Cluster.new(@amq, 443, "the_identity", @serializer, @mapper, "localhost:1234")
          cluster.nanites.instance_of?(Nanite::State).should == true
        end
      end
    end
  end # Intialization



  
  describe "Nanite timed out" do
    before(:each) do
      @fanout = mock("fanout")
      @binding = mock("binding", :subscribe => true)
      @queue = mock("queue", :bind => @binding)
      @amq = mock("AMQueue", :queue => @queue, :fanout => @fanout)
      @serializer = mock("Serializer")
      Nanite::Log.stub!(:info)
      @register_packet = Nanite::Register.new("nanite_id", ["the_nanite_services"], "nanite_status",[])
    end
    
    it "should remove the nanite when timed out" do
      EM.run do
        @cluster = Nanite::Cluster.new(@amq, 0.01, "the_identity", @serializer, @mapper)
        @cluster.register(@register_packet)
        EM.add_timer(1.1) {
          @cluster.nanites["nanite_id"].should == nil
          EM.stop_event_loop
        }
      end
    end
    
    it "should call the timed out callback handler when registered" do
      EM.run do
        @cluster = Nanite::Cluster.new(@amq, 0.01, "the_identity", @serializer, @mapper)
        @cluster.register(@register_packet)
        @cluster.should_receive(:nanite_timed_out).twice
        EM.add_timer(1.1) {
          EM.stop_event_loop
        }
      end
    end
    
    it "should not remove the agent when the callback returned false" do
      EM.run do
        @cluster = Nanite::Cluster.new(@amq, 0.01, "the_identity", @serializer, @mapper)
        @cluster.register(@register_packet)
        @cluster.stub!(:nanite_timed_out).and_return(false)
        EM.add_timer(1.1) {
          @cluster.nanites["nanite_id"].should_not == nil
          EM.stop_event_loop
        }
      end
    end
  end

 
    describe "when timing out after a heartbeat" do
      it "should remove the nanite" do
        run_in_em(false) do
          @cluster = Nanite::Cluster.new(@amq, 0.1, "the_identity", @serializer, @mapper)
          @cluster.nanites["nanite_id"] = {:status => "nanite_status"}
          @cluster.send :handle_ping, @ping
          EM.add_timer(1.5) do
            @cluster.nanites["nanite_id"].should == nil
            EM.stop_event_loop
          end
        end
      end
      
      it "should call the timeout callback when defined" do
        run_in_em(false) do
          @timeout_callback = lambda {|nanite, mapper| }
          @timeout_callback.should_receive(:call).with("nanite_id", @mapper)
          @cluster = Nanite::Cluster.new(@amq, 0.1, "the_identity", @serializer, @mapper, nil, :timeout => @timeout_callback)
          @cluster.nanites["nanite_id"] = {:status => "nanite_status"}
          @cluster.send :handle_ping, @ping
          EM.add_timer(1.5) do
            EM.stop_event_loop
          end
        end
      end
    end
  end
end # Nanite::Cluster
