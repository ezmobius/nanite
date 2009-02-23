require File.dirname(__FILE__) + '/spec_helper'
require 'nanite'

describe "Agent:" do

  describe "Default Option" do

    before(:all) do
      EM.stub!(:add_periodic_timer)
      AMQP.stub!(:connect)
      @amq = mock("AMQueue", :queue => mock("queue", :subscribe => {}), :fanout => mock("fanout", :publish => nil))
      MQ.stub!(:new).and_return(@amq)
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

  describe "Options from config.yml" do

    before(:all) do
      @agent = Nanite::Agent.start
    end

  end

  describe "Passed in Options" do

    before(:each) do
      EM.stub!(:add_periodic_timer)
      AMQP.stub!(:connect)
      @amq = mock("AMQueue", :queue => mock("queue", :subscribe => {}), :fanout => mock("fanout", :publish => nil))
      MQ.stub!(:new).and_return(@amq)
    end

    # TODO figure out how to stub call to daemonize
    # it "for daemonize should override default (false)" do
    #   agent = Nanite::Agent.start(:daemonize => true)
    #   agent.options.should include(:daemonize)
    #   agent.options[:daemonize].should == true
    # end

    it "for format should override default (marshal)" do
      agent = Nanite::Agent.start(:format => :json)
      agent.options.should include(:format)
      agent.options[:format].should == :json
    end

    # TODO figure out how to avoid console output
    # it "for console should override default (false)" do
    #   agent = Nanite::Agent.start(:console => true)
    #   agent.options.should include(:console)
    #   agent.options[:console].should == true
    # end

    it "for user should override default (nanite)" do
      agent = Nanite::Agent.start(:user => "me")
      agent.options.should include(:user)
      agent.options[:user].should == "me"
    end

    it "for pass(word) should override default (testing)" do
      agent = Nanite::Agent.start(:pass => "secret")
      agent.options.should include(:pass)
      agent.options[:pass].should == "secret"
    end

    it "for secure should override default (false)" do
      agent = Nanite::Agent.start(:secure => true)
      agent.options.should include(:secure)
      agent.options[:secure].should == true
    end

    it "for host should override default (0.0.0.0)" do
      agent = Nanite::Agent.start(:host => "127.0.0.1")
      agent.options.should include(:host)
      agent.options[:host].should == "127.0.0.1"
    end

    it "for log_level should override default (info)" do
      agent = Nanite::Agent.start(:log_level => :debug)
      agent.options.should include(:log_level)
      agent.options[:log_level].should == :debug
    end

    it "for vhost should override default (/nanite)" do
      agent = Nanite::Agent.start(:vhost => "/virtual_host")
      agent.options.should include(:vhost)
      agent.options[:vhost].should == "/virtual_host"
    end

    it "for ping_time should override default (15)" do
      agent = Nanite::Agent.start(:ping_time => 5)
      agent.options.should include(:ping_time)
      agent.options[:ping_time].should == 5
    end

    it "for default_services should override default ([])" do
      agent = Nanite::Agent.start(:default_services => [:test])
      agent.options.should include(:default_services)
      agent.options[:default_services].should == [:test]
    end

    it "for root should override default (#{File.expand_path(File.join(File.dirname(__FILE__), '..'))})" do
      agent = Nanite::Agent.start(:root => File.expand_path(File.dirname(__FILE__)))
      agent.options.should include(:root)
      agent.options[:root].should == File.expand_path(File.dirname(__FILE__))
    end

    it "for file_root should override default (#{File.expand_path(File.join(File.dirname(__FILE__), '..', 'files'))})" do
      agent = Nanite::Agent.start(:file_root => File.expand_path(File.dirname(__FILE__)))
      agent.options.should include(:file_root)
      agent.options[:file_root].should == File.expand_path(File.dirname(__FILE__))
    end

  end

end
