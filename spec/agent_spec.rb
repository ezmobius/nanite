require File.dirname(__FILE__) + '/spec_helper'
require 'nanite'

describe "Agent:" do

  before(:all) do
    EM.stub!(:add_periodic_timer)
    AMQP.stub!(:connect)
    @amq = mock("AMQueue", :queue => mock("queue", :subscribe => {}), :fanout => mock("fanout", :publish => nil))
    MQ.stub!(:new).and_return(@amq)
  end

  describe "Default Option" do

    before(:all) do
      @agent = Nanite::Agent.start
    end

    it "for daemonize is false" do
      @agent.options.should include(:daemonize)
      @agent.options[:daemonize].should == false
    end

    it "for format is marshal" do
      @agent.options.should include(:format)
      @agent.options[:format].should == :marshal
    end

    it "for console is false" do
      @agent.options.should include(:console)
      @agent.options[:console].should == false
    end

    it "for user is nanite" do
      @agent.options.should include(:user)
      @agent.options[:user].should == "nanite"
    end

    it "for pass(word) is testing" do
      @agent.options.should include(:pass)
      @agent.options[:pass].should == "testing"
    end

    it "for secure is false" do
      @agent.options.should include(:secure)
      @agent.options[:secure].should == false
    end

    it "for host is 0.0.0.0" do
      @agent.options.should include(:host)
      @agent.options[:host].should == "0.0.0.0"
    end

    it "for log_level is info" do
      @agent.options.should include(:log_level)
      @agent.options[:log_level].should == :info
    end

    it "for vhost is /nanite" do
      @agent.options.should include(:vhost)
      @agent.options[:vhost].should == "/nanite"
    end

    it "for ping_time is 15" do
      @agent.options.should include(:ping_time)
      @agent.options[:ping_time].should == 15
    end

    it "for default_services is []" do
      @agent.options.should include(:default_services)
      @agent.options[:default_services].should == []
    end

    it "for root is #{File.expand_path(File.join(File.dirname(__FILE__), '..'))}" do
      @agent.options.should include(:root)
      @agent.options[:root].should == File.expand_path(File.join(File.dirname(__FILE__), '..'))
    end

    it "for file_root is #{File.expand_path(File.join(File.dirname(__FILE__), '..', 'files'))}" do
      @agent.options.should include(:file_root)
      @agent.options[:file_root].should == File.expand_path(File.join(File.dirname(__FILE__), '..', 'files'))
    end
  end

end
