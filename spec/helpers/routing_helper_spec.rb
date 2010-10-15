require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Nanite::Helpers::RoutingHelper do
  include Nanite::Helpers::RoutingHelper

  describe "Target Selection" do
    before(:each) do
      @all_known_nanites = [
        ['nanite-1', {
          :status => 0.21,
          :services => ['/foo/bar', '/you/too'],
          :tags => ['a', 'b', 'c'],
          :timestamp => Time.now
        }],
        ['nanite-2', {
          :status => 1.99,
          :services => ['/foo/bar', '/you/too', '/maybe/he'],
          :tags => ['b', 'c', 'e'],
          :timestamp => Time.now
        }],
        ['nanite-3', {
          :status => 0.5,
          :services => ['/foo/bar', '/maybe/he'],
          :tags => [],
          :timestamp => Time.now - 60 * 10
        }],
        ['nanite-4', {
          :status => 2.01,
          :services => ['/foo/bar', '/you/too'],
          :tags => ['a', 'b', 'c'],
          :timestamp => Time.now - 10
        }],
      ]
    end

    it "should return array containing targets for request" do
      target = mock("Supplied Target")
      request = mock("Request", :target => target)
      targets_for(request).should be_instance_of(Array)
    end

    it "should use target from request" do
      target = mock("Supplied Target")
      request = mock("Request", :target => target)
      targets_for(request).should == [target]
    end

    it "should use targets choosen by least loaded selector (:least_loaded)" do
      request = mock("Request", :target => nil, :selector => :least_loaded, :type => "/foo/bar", :tags => [])
      self.should_receive(:nanites_providing).with('/foo/bar', []).and_return(@all_known_nanites)
      
      targets_for(request).should == ["nanite-1"]
    end

    it "should use targets choosen by all selector (:all)" do
      request = mock("Request", :target => nil, :selector => :all, :type => "/foo/bar", :tags => [])
      self.should_receive(:nanites_providing).with('/foo/bar', []).and_return(@all_known_nanites)
      
      targets_for(request).should == ["nanite-1", "nanite-2", "nanite-3", "nanite-4"]
    end

    it "should use targets choosen by random selector (:random)" do
      request = mock("Request", :target => nil, :selector => :random, :type => "/foo/bar", :tags => [])
      self.should_receive(:nanites_providing).with('/foo/bar', []).and_return(@all_known_nanites)
  
      self.should_receive(:rand).with(4).and_return(2)
      targets_for(request).should == ["nanite-3"]
    end

    it "should use targets choosen by round-robin selector (:rr)" do
      request = mock("Request", :target => nil, :selector => :rr, :type => "/foo/bar", :tags => [])
      self.stub!(:nanites_providing).with('/foo/bar', []).and_return(@all_known_nanites)
      
      self.instance_variable_set("@last", {})
      
      targets_for(request).should == ["nanite-1"]
      targets_for(request).should == ["nanite-2"]
      targets_for(request).should == ["nanite-3"]
      targets_for(request).should == ["nanite-4"]
      targets_for(request).should == ["nanite-1"]
      targets_for(request).should == ["nanite-2"]
      targets_for(request).should == ["nanite-3"]
      targets_for(request).should == ["nanite-4"]
    end
    
    it "should pass the tag filter down" do
      request = mock("Request", :target => nil, :selector => :least_loaded, :type => "/foo/bar", :tags => ['a'])
      self.should_receive(:nanites_providing).with('/foo/bar', ['a']).and_return(@all_known_nanites)
  
      targets_for(request).should == ["nanite-1"]
    end

    context "when handling timed out nanites" do
      let(:agent_timeout) {15}

      before(:each) do
        @nanites = mock("Nanites", :nanites_for => @all_known_nanites)
        @nanites.stub(:delete)
        self.stub!(:nanites).and_return(@nanites)
      end
    
      it "should not return timedout nanites" do
        @all_known_nanites[0][1][:timestamp] = Time.local(2000)
      
        request = mock("Request", :target => nil, :selector => :least_loaded, :type => "/foo/bar", :tags => [])
      
        targets_for(request).should == ["nanite-2"]
      end
    
      it "should not return timedout nanites - even when loading all nanites" do
        @all_known_nanites[0][1][:timestamp] = Time.local(2000)
      
        request = mock("Request", :target => nil, :selector => :all, :type => "/foo/bar", :tags => [])
      
        targets_for(request).should == ["nanite-2", "nanite-4"]
      end
    
      it "should delete timedout nanites from state and reaper" do
        @all_known_nanites[0][1][:timestamp] = Time.local(2000)
      
        @nanites.should_receive(:delete).with(@all_known_nanites[0][0])
      
        @nanites.should_receive(:delete).with(@all_known_nanites[2][0])
      
        request = mock("Request", :target => nil, :selector => :all, :type => "/foo/bar", :tags => [])
      
        targets_for(request).should == ["nanite-2", "nanite-4"]
      end
    end
  end

end
