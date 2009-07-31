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

    describe "of Heartbeat (Queue)" do

      it "should setup the heartbeat (queue) for id" do
        @amq.should_receive(:queue).with("heartbeat-the_identity", anything()).and_return(@queue)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @serializer, @mapper)
      end

      it "should make the heartbeat (queue) exclusive" do
        @amq.should_receive(:queue).with("heartbeat-the_identity", { :exclusive => true }).and_return(@queue)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @serializer, @mapper)
      end

      it "should bind the heartbeat (queue) to 'heartbeat' fanout" do
        @amq.should_receive(:fanout).with("heartbeat", { :durable => true }).and_return(@fanout)
        @queue.should_receive(:bind).with(@fanout).and_return(@binding)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @serializer, @mapper)
      end

    end # of Heartbeat (Queue)


    describe "of Registration (Queue)" do

      it "should setup the registration (queue) for id" do
        @amq.should_receive(:queue).with("registration-the_identity", anything()).and_return(@queue)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @serializer, @mapper)
      end

      it "should make the registration (queue) exclusive" do
        @amq.should_receive(:queue).with("registration-the_identity", { :exclusive => true }).and_return(@queue)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @serializer, @mapper)
      end

      it "should bind the registration (queue) to 'registration' fanout" do
        @amq.should_receive(:fanout).with("registration", { :durable => true }).and_return(@fanout)
        @queue.should_receive(:bind).with(@fanout).and_return(@binding)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @serializer, @mapper)
      end

    end # of Registration (Queue)

    describe "of Request (Queue)" do

      it "should setup the request (queue) for id" do
        @amq.should_receive(:queue).with("request-the_identity", anything()).and_return(@queue)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @serializer, @mapper)
      end

      it "should make the request (queue) exclusive" do
        @amq.should_receive(:queue).with("request-the_identity", { :exclusive => true }).and_return(@queue)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @serializer, @mapper)
      end

      it "should bind the request (queue) to 'request' fanout" do
        @amq.should_receive(:fanout).with("request", { :durable => true }).and_return(@fanout)
        @queue.should_receive(:bind).with(@fanout).and_return(@binding)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @serializer, @mapper)
      end

    end # of Request (Queue)


    describe "Reaper" do

      it "should be created" do
        Nanite::Reaper.should_receive(:new).with(anything()).and_return(@reaper)
        cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @serializer, @mapper)
      end

      it "should use the agent timeout" do
        Nanite::Reaper.should_receive(:new).with(443).and_return(@reaper)
        cluster = Nanite::Cluster.new(@amq, 443, "the_identity", @serializer, @mapper)
      end

    end # Reaper

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


  describe "Target Selection" do

    before(:each) do
      @fanout = mock("fanout")
      @binding = mock("binding", :subscribe => true)
      @queue = mock("queue", :bind => @binding)
      @amq = mock("AMQueue", :queue => @queue, :fanout => @fanout)
      @serializer = mock("Serializer")
      @reaper = mock("Reaper")
      Nanite::Reaper.stub!(:new).and_return(@reaper)
      @cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @serializer, @mapper)
    end

    it "should return array containing targets for request" do
      target = mock("Supplied Target")
      request = mock("Request", :target => target)
      @cluster.targets_for(request).should be_instance_of(Array)
    end

    it "should use target from request" do
      target = mock("Supplied Target")
      request = mock("Request", :target => target)
      @cluster.targets_for(request).should == [target]
    end

    it "should use targets choosen by least loaded selector (:least_loaded)" do
      targets = { "target 3" => 3 }
      request = mock("Request", :target => nil, :selector => :least_loaded, :type => "service", :tags => [])
      @cluster.should_receive(:least_loaded).with("service", []).and_return(targets)
      @cluster.targets_for(request).should == ["target 3"]
    end

    it "should use targets choosen by all selector (:all)" do
      targets = { "target 1" => 1, "target 2" => 2, "target 3" => 3 }
      request = mock("Request", :target => nil, :selector => :all, :type => "service", :tags => [])
      @cluster.should_receive(:all).with("service", []).and_return(targets)
      @cluster.targets_for(request).should == ["target 1", "target 2", "target 3"]
    end

    it "should use targets choosen by random selector (:random)" do
      targets = { "target 3" => 3 }
      request = mock("Request", :target => nil, :selector => :random, :type => "service", :tags => [])
      @cluster.should_receive(:random).with("service", []).and_return(targets)
      @cluster.targets_for(request).should == ["target 3"]
    end

    it "should use targets choosen by round-robin selector (:rr)" do
      targets = { "target 2" => 2 }
      request = mock("Request", :target => nil, :selector => :rr, :type => "service", :tags => [])
      @cluster.should_receive(:rr).with("service", []).and_return(targets)
      @cluster.targets_for(request).should == ["target 2"]
    end

  end # Target Selection


  describe "Nanite Registration" do

    before(:each) do
      @fanout = mock("fanout")
      @binding = mock("binding", :subscribe => true)
      @queue = mock("queue", :bind => @binding)
      @amq = mock("AMQueue", :queue => @queue, :fanout => @fanout)
      @serializer = mock("Serializer")
      @reaper = mock("Reaper", :timeout => true)
      Nanite::Log.stub!(:info)
      Nanite::Reaper.stub!(:new).and_return(@reaper)
      @cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @serializer, @mapper)
      @register_packet = Nanite::Register.new("nanite_id", ["the_nanite_services"], "nanite_status",[])
    end

    it "should add the Nanite to the nanites map" do
      @cluster.register(@register_packet)
      @cluster.nanites['nanite_id'].should_not be_nil
    end

    it "should use hash of the Nanite's services and status as value" do
      @cluster.register(@register_packet)
      @cluster.nanites['nanite_id'].keys.size == 2
      @cluster.nanites['nanite_id'].keys.should include(:services)
      @cluster.nanites['nanite_id'].keys.should include(:status)
      @cluster.nanites['nanite_id'][:services].should ==  ["the_nanite_services"]
      @cluster.nanites['nanite_id'][:status].should ==  "nanite_status"
    end

    it "should add nanite to reaper" do
      @reaper.should_receive(:timeout).with('nanite_id', 33)
      @cluster.register(@register_packet)
    end

    it "should log info message that nanite was registered" do
      Nanite::Log.should_receive(:info)
      @cluster.register(@register_packet)
    end

    describe "with registered callbacks" do
      before(:each) do
        @register_callback = lambda {|request, mapper|}
        @cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @serializer, @mapper, nil, :register =>  @register_callback)
      end
      
      it "should call the registration callback" do
        @register_callback.should_receive(:call).with("nanite_id", @mapper)
        @cluster.register(@register_packet)
      end
    end
    
    describe "when sending an invalid packet to the registration queue" do
      it "should log a message statement" do
        Nanite::Log.logger.should_receive(:warn).with("RECV [register] Invalid packet type: Nanite::Ping")
        @cluster.register(Nanite::Ping.new(nil, nil))
      end
    end
  end # Nanite Registration

  describe "Unregister" do
    before(:each) do
      @fanout = mock("fanout")
      @binding = mock("binding", :subscribe => true)
      @queue = mock("queue", :bind => @binding)
      @amq = mock("AMQueue", :queue => @queue, :fanout => @fanout)
      @serializer = mock("Serializer")
      @reaper = mock("Reaper", :timeout => true)
      Nanite::Log.stub!(:info)
      Nanite::Reaper.stub!(:new).and_return(@reaper)
      @cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @serializer, @mapper)
      @cluster.nanites["nanite_id"] = "nanite_id"
      @unregister_packet = Nanite::UnRegister.new("nanite_id")
    end
    
    it "should delete the nanite" do
      @cluster.register(@unregister_packet)
      @cluster.nanites["nanite_id"].should == nil
    end
    
    describe "with registered callbacks" do
      before(:each) do
        @unregister_callback = lambda {|request, mapper| }
        @cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @serializer, @mapper, nil, :unregister => @unregister_callback)
        @cluster.nanites["nanite_id"] = "nanite_id"
      end
      
      it "should call the unregister callback" do
        @unregister_callback.should_receive(:call).with("nanite_id", @mapper)
        @cluster.register(@unregister_packet)
      end
    end
  end
  
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
        EM.add_timer(1.1) {
          @cluster.nanites["nanite_id"].should == nil
          EM.stop_event_loop
        }
      end
    end
  end
  
  describe "Route" do

    before(:each) do
      @fanout = mock("fanout")
      @binding = mock("binding", :subscribe => true)
      @queue = mock("queue", :bind => @binding)
      @amq = mock("AMQueue", :queue => @queue, :fanout => @fanout)
      @serializer = mock("Serializer")
      @reaper = mock("Reaper")
      Nanite::Reaper.stub!(:new).and_return(@reaper)
      @cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @serializer, @mapper)
      @request = mock("Request")
    end

    it "should publish request to all targets" do
      target1 = mock("Target 1")
      target2 = mock("Target 2")
      @cluster.should_receive(:publish).with(@request, target1)
      @cluster.should_receive(:publish).with(@request, target2)
      EM.run {
        @cluster.route(@request, [target1, target2])
        EM.stop
      }
    end

  end # Route


  describe "Publish" do

    before(:each) do
      @fanout = mock("fanout")
      @binding = mock("binding", :subscribe => true)
      @queue = mock("queue", :bind => @binding, :publish => true)
      @amq = mock("AMQueue", :queue => @queue, :fanout => @fanout)
      @serializer = mock("Serializer", :dump => "dumped_value")
      @reaper = mock("Reaper")
      Nanite::Reaper.stub!(:new).and_return(@reaper)
      @cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @serializer, @mapper)
      @request = mock("Request", :persistent => true, :target => nil, :target= => nil, :to_s => nil)
      @target = mock("Target of Request")
    end

    it "should serialize request before publishing it" do
      @request.should_receive(:target=).with(@target)
      @request.should_receive(:target=)
      @request.should_receive(:target)
      @serializer.should_receive(:dump).with(@request).and_return("serialized_request")
      @cluster.publish(@request, @target)
    end

    it "should publish request to target queue" do
      @request.should_receive(:target=).with(@target)
      @request.should_receive(:target=)
      @request.should_receive(:target)
      @queue.should_receive(:publish).with("dumped_value", anything())
      @cluster.publish(@request, @target)
    end

    it "should persist request based on request setting" do
      @request.should_receive(:target=).with(@target)
      @request.should_receive(:target=)
      @request.should_receive(:target)
      @request.should_receive(:persistent).and_return(false)
      @queue.should_receive(:publish).with(anything(), { :persistent => false })
      @cluster.publish(@request, @target)
    end

  end # Publish
  
  describe "Agent Request Handling" do

    before(:each) do
      @fanout = mock("fanout")
      @binding = mock("binding", :subscribe => true)
      @queue = mock("queue", :bind => @binding, :publish => true)
      @amq = mock("AMPQueue", :queue => @queue, :fanout => @fanout)
      @serializer = mock("Serializer", :dump => "dumped_value")
      @target = mock("Target of Request")
      @reaper = mock("Reaper")
      Nanite::Reaper.stub!(:new).and_return(@reaper)
      @request_without_target = mock("Request", :target => nil, :token => "Token",
       :reply_to => "Reply To", :from => "From", :persistent => true, :identity => "Identity",
       :payload => "Payload", :to_s => nil)
      @request_with_target = mock("Request", :target => "Target", :token => "Token",
       :reply_to => "Reply To", :from => "From", :persistent => true, :payload => "Payload", :to_s => nil)
      @mapper_with_target = mock("Mapper", :identity => "id")
      @mapper_without_target = mock("Mapper", :request => false, :identity => @request_without_target.identity)
      @cluster_with_target = Nanite::Cluster.new(@amq, 32, "the_identity", @serializer, @mapper_with_target)
      @cluster_without_target = Nanite::Cluster.new(@amq, 32, "the_identity", @serializer, @mapper_without_target)
      Nanite::Cluster.stub!(:mapper).and_return(@mapper)
    end
    
    it "should forward requests with targets" do
      @mapper_with_target.should_receive(:send_request).with(@request_with_target, anything())
      @cluster_with_target.__send__(:handle_request, @request_with_target)
    end
    
    it "should reply back with nil results for requests with no target when offline queue is disabled" do
      @mapper_without_target.should_receive(:send_request).with(@request_without_target, anything())
      Nanite::Result.should_receive(:new).with(@request_without_target.token, @request_without_target.from, nil, @request_without_target.identity)
      @cluster_without_target.__send__(:handle_request, @request_without_target)
    end
    
    it "should hand in an intermediate handler" do
      @mapper_with_target.should_receive(:send_request) do |request, opts|
        opts[:intermediate_handler].should be_instance_of(Proc)
      end
      
      @cluster_with_target.__send__(:handle_request, @request_with_target)
    end

    it "should forward the message when send_request failed" do
      @mapper_with_target.stub!(:send_request).and_return(false)
      @cluster_with_target.should_receive(:forward_response)
      @cluster_with_target.__send__(:handle_request, @request_with_target)
    end
  end # Agent Request Handling

  describe "Heartbeat" do
    before(:each) do
      @fanout = mock("fanout")
      @binding = mock("binding", :subscribe => true)
      @queue = mock("queue", :bind => @binding, :publish => true)
      @amq = mock("AMQueue", :queue => @queue, :fanout => @fanout)
      @serializer = mock("Serializer", :dump => "dumped_value")
      Nanite::Log.stub!(:info)
      @ping = stub("ping", :status => 0.3, :identity => "nanite_id")
    end
    
    it "should update the nanite status" do
      run_in_em do
        @cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @serializer, @mapper)
        @cluster.nanites["nanite_id"] = {:status => "nanite_status"}
        @cluster.send :handle_ping, @ping
        @cluster.nanites["nanite_id"][:status].should == 0.3
      end
    end
    
    it "should reset the agent time out" do
      run_in_em do
        @cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @serializer, @mapper)
        @cluster.reaper.should_receive(:reset_with_autoregister_hack).with("nanite_id", 33)
        @cluster.nanites["nanite_id"] = {:status => "nanite_status"}
        @cluster.send :handle_ping, @ping
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
