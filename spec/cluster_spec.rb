require File.dirname(__FILE__) + '/spec_helper'
require 'nanite'

describe Nanite::Cluster do

  describe "Intialization" do

    before(:each) do
      @fanout = mock("fanout")
      @binding = mock("binding", :subscribe => true)
      @queue = mock("queue", :bind => @binding)
      @amq = mock("AMQueue", :queue => @queue, :fanout => @fanout)
      @log = mock("Log")
      @serializer = mock("Serializer")
      @reaper = mock("Reaper")
      Nanite::Reaper.stub!(:new).and_return(@reaper)
    end

    describe "of Heartbeat (Queue)" do

      it "should setup the heartbeat (queue) for id" do
        @amq.should_receive(:queue).with("heartbeat-the_identity", anything()).and_return(@queue)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @log, @serializer)
      end

      it "should make the heartbeat (queue) exclusive" do
        @amq.should_receive(:queue).with("heartbeat-the_identity", { :exclusive => true }).and_return(@queue)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @log, @serializer)
      end

      it "should bind the heartbeat (queue) to 'heartbeat' fanout" do
        @amq.should_receive(:fanout).with("heartbeat", { :durable => true }).and_return(@fanout)
        @queue.should_receive(:bind).with(@fanout).and_return(@binding)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @log, @serializer)
      end

    end # of Heartbeat (Queue)


    describe "of Registration (Queue)" do

      it "should setup the registration (queue) for id" do
        @amq.should_receive(:queue).with("registration-the_identity", anything()).and_return(@queue)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @log, @serializer)
      end

      it "should make the registration (queue) exclusive" do
        @amq.should_receive(:queue).with("registration-the_identity", { :exclusive => true }).and_return(@queue)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @log, @serializer)
      end

      it "should bind the registration (queue) to 'registration' fanout" do
        @amq.should_receive(:fanout).with("registration", { :durable => true }).and_return(@fanout)
        @queue.should_receive(:bind).with(@fanout).and_return(@binding)
        cluster = Nanite::Cluster.new(@amq, 10, "the_identity", @log, @serializer)
      end

    end # of Registration (Queue)


    describe "Reaper" do

      it "should be created" do
        Nanite::Reaper.should_receive(:new).with(anything()).and_return(@reaper)
        cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @log, @serializer)
      end

      it "should use the agent timeout" do
        Nanite::Reaper.should_receive(:new).with(443).and_return(@reaper)
        cluster = Nanite::Cluster.new(@amq, 443, "the_identity", @log, @serializer)
      end

    end # Reaper

  end # Intialization


  describe "Nanite Registration" do

    before(:each) do
      @fanout = mock("fanout")
      @binding = mock("binding", :subscribe => true)
      @queue = mock("queue", :bind => @binding)
      @amq = mock("AMQueue", :queue => @queue, :fanout => @fanout)
      @log = mock("Log", :info => true)
      @serializer = mock("Serializer")
      @reaper = mock("Reaper", :timeout => true)
      Nanite::Reaper.stub!(:new).and_return(@reaper)
      @cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @log, @serializer)
      @nanite = mock("Nanite", :identity => "nanite_id", :services => "the_nanite_services", :status => "nanite_status")
    end

    it "should add the Nanite to the nanites map" do
      @cluster.register(@nanite)
      @cluster.nanites.keys.should include('nanite_id')
      @cluster.nanites['nanite_id'].should_not be_nil
    end

    it "should use hash of the Nanite's services and status as value" do
      @cluster.register(@nanite)
      @cluster.nanites['nanite_id'].keys.size == 2
      @cluster.nanites['nanite_id'].keys.should include(:services)
      @cluster.nanites['nanite_id'].keys.should include(:status)
      @cluster.nanites['nanite_id'][:services].should ==  "the_nanite_services"
      @cluster.nanites['nanite_id'][:status].should ==  "nanite_status"
    end

    it "should add nanite to reaper" do
      @reaper.should_receive(:timeout).with('nanite_id', 33)
      @cluster.register(@nanite)
    end

    it "should log info message that nanite was registered" do
      @log.should_receive(:info).with("registered: nanite_id, servicesthe_nanite_servicesstatusnanite_status")
      @cluster.register(@nanite)
    end

  end # Nanite Registration


  describe "Route" do

    before(:each) do
      @fanout = mock("fanout")
      @binding = mock("binding", :subscribe => true)
      @queue = mock("queue", :bind => @binding)
      @amq = mock("AMQueue", :queue => @queue, :fanout => @fanout)
      @log = mock("Log")
      @serializer = mock("Serializer")
      @reaper = mock("Reaper")
      Nanite::Reaper.stub!(:new).and_return(@reaper)
      @cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @log, @serializer)
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
      @log = mock("Log")
      @serializer = mock("Serializer", :dump => "dumped_value")
      @reaper = mock("Reaper")
      Nanite::Reaper.stub!(:new).and_return(@reaper)
      @cluster = Nanite::Cluster.new(@amq, 32, "the_identity", @log, @serializer)
      @request = mock("Request", :persistent => true)
      @target = mock("Target of Request")
    end

    it "should serialize request before publishing it" do
      @serializer.should_receive(:dump).with(@request).and_return("serialized_request")
      @cluster.publish(@request, @target)
    end

    it "should publish request to target queue" do
      @queue.should_receive(:publish).with("dumped_value", anything())
      @cluster.publish(@request, @target)
    end

    it "should persist request based on request setting" do
      @request.should_receive(:persistent).and_return(false)
      @queue.should_receive(:publish).with(anything(), { :persistent => false })
      @cluster.publish(@request, @target)
    end

  end # Publish

end # Nanite::Cluster
