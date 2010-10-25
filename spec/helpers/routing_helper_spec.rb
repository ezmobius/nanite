require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Nanite::Helpers::RoutingHelper do
  include Nanite::Helpers::RoutingHelper

  describe "Finding targets" do
    let(:options) do
      {:agent_timeout => 900}
    end

    before(:each) do
      setup_state nil
      nanites['nanite-1'] = {
          :status => 0.21,
          :services => ['/foo/bar', '/you/too'],
          :tags => ['a', 'b', 'c'],
          :timestamp => Time.now
        }
      nanites['nanite-2'] = {
          :status => 1.99,
          :services => ['/foo/bar', '/you/too', '/maybe/he'],
          :tags => ['b', 'c', 'e'],
          :timestamp => Time.now
        }
      nanites['nanite-3'] = {
          :status => 0.5,
          :services => ['/foo/bar', '/maybe/he'],
          :tags => [],
          :timestamp => Time.now - 60 * 10
        }
      nanites['nanite-4'] = {
          :status => 2.01,
          :services => ['/foo/bar', '/you/too'],
          :tags => ['a', 'b', 'c'],
          :timestamp => Time.now - 10
        }
    end

    after do
      reset_state
    end

    it "should return array containing targets for request" do
      request = Nanite::Request.new('/agent/log', 'message')
      targets_for(request).should be_instance_of(Array)
    end

    it "should use target from request" do
      request = Nanite::Request.new('/agent/log', 'message')
      request.target = 'nanite-1234'
      targets_for(request).should == ['nanite-1234']
    end

    it "should use targets choosen by least loaded selector (:least_loaded)" do
      request = Nanite::Request.new('/foo/bar', 'message')
      targets_for(request).should == ["nanite-1"]
    end

    it "should use targets choosen by all selector (:all)" do
      request = Nanite::Request.new('/foo/bar', 'message')
      request.selector = :all
      targets_for(request).should == ["nanite-1", "nanite-2", "nanite-3", "nanite-4"]
    end

    it "should use targets choosen by random selector (:random)" do
      request = Nanite::Request.new('/foo/bar', 'message')
      request.selector = :random
      targets_for(request).should have(1).item
      nanites[targets_for(request).first].should_not == nil
    end

    it "should use targets choosen by round-robin selector (:rr)" do
      request = Nanite::Request.new('/foo/bar', 'message')
      request.selector = :rr
      
      @last = {}
      
      targets_for(request).should == ["nanite-1"]
      targets_for(request).should == ["nanite-2"]
      targets_for(request).should == ["nanite-3"]
      targets_for(request).should == ["nanite-4"]
      targets_for(request).should == ["nanite-1"]
      targets_for(request).should == ["nanite-2"]
      targets_for(request).should == ["nanite-3"]
      targets_for(request).should == ["nanite-4"]
    end
    
    it "should filter with tag" do
      request = Nanite::Request.new('/foo/bar', 'message')
      request.tags = ["a"]
      targets_for(request).should == ["nanite-1"]
    end

    context "when handling timed out nanites" do
      before(:each) do
        options[:agent_timeout] = 15
      end
    
      it "should not return timed-out nanites" do
        request = Nanite::Request.new('/foo/bar', 'message')
        nanites['nanite-2'][:timestamp] = Time.local(2000)
        targets_for(request).should_not include("nanite-2")
      end
    
   
      it "should delete timedout nanites from state and reaper" do
        nanites['nanite-1'][:timestamp] = Time.local(2000)
        request = Nanite::Request.new('/foo/bar', 'message')
        request.selector = :all
        targets_for(request).should == ["nanite-2", "nanite-4"]
        nanites['nanite-1'].should == nil
      end
    end
  end

end
