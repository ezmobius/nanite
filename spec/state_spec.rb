require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'nanite/state'

require 'set'

describe ::Nanite::State do
  
  class ::Redis
    attr_accessor :options

    def initialize(options)
      @options = options
      @hash = {}
    end

    attr_accessor :hash
    
    def get(key)
      hash[key]
    end
    alias :[] :get
    
    def delete(key)
      hash.delete(key)
    end
    alias :del :delete
    
    def set(key, value)
      hash[key] = value.to_s
    end
    alias :[]= :set

    def sadd(key, value)
      hash[key] ||= Set.new
      hash[key].add(value.to_s)
    end

    def smembers(key)
      (hash[key] || []).to_a
    end

    def sismember(key, value)
      hash[key] && hash[key].member?(value.to_s)
    end

    def srem(key, value)
      hash[key] && hash[key].delete(value.to_s)
    end

    def sinter(keys)
      sets = keys.collect{|key| get(key) || Set.new}
      result = sets.pop
      sets.each do |set|
        result = result.intersection(set)
      end
      result
    end

    def scard(key)
      hash[key].size
    end
    
    def quit
    end
   
    def keys(match)
      hash.keys
    end
    
    def flushdb()
      @hash = {}
    end
  end

  context "Setting up Redis" do
    it "should accept a string with just a host name" do
      state = Nanite::State.new("localhost:6380")
      state.redis.options[:host].should == 'localhost'
      state.redis.options[:port].should == '6380'
    end

    it "should default to 127.0.0.1 and port 6379" do
      state = Nanite::State.new('')
      state.redis.options[:host].should == '127.0.0.1'
      state.redis.options[:port].should == '6379'
    end

    it "should accept a hash of options to pass to Redis" do
      state = Nanite::State.new(:host => 'localhost', :port => '6380', :timeout => 10)
      state.redis.options[:host].should == 'localhost'
      state.redis.options[:port].should == '6380'
      state.redis.options[:timeout].should == 10
    end
  end

  context "State lifecycle" do
    before(:each) do
      @state = Nanite::State.new('')
    end

    context "adding a node" do
      before(:each) do
        @state['nanite-1234'] = {:status => "0.1", :services => ["/agent/log"], :tags => ["log"]}
      end
    
      it "should set the attributes for the node" do
        @state['nanite-1234'][:status].should == "0.1"
        @state['nanite-1234'][:services].should == ["/agent/log"]
        @state['nanite-1234'][:tags].should == ["log"]
      end

      it "should set a timestamp" do
        @state["nanite-1234"][:timestamp].should be_close(Time.now.utc.to_i, 1)
      end

      it "should add the services to the list of services" do
        @state.all_services.should include("/agent/log")
      end

      it "should add the tags to the list of tags" do
        @state.all_tags.should include("log")
      end

      it "should add the identity to a set of all nanites" do
        @state.redis.smembers("nanite:nanites").should include("nanite-1234")
      end
    end

    context "looking up a node" do

      before(:each) do
        @state['nanite-1234'] = {:status => "0.1", :services => ["/agent/log"], :tags => ["log"]}
        @state['nanite-1235'] = {:status => "0.1", :services => ["/agent/log"], :tags => ["mapreduce"]}
        @state['nanite-1236'] = {:status => "0.1", :services => ["/agent/load"], :tags => []} 
      end

      it "should fetch all nanites for a given service" do
        agents = @state.nanites_for("/agent/log").collect {|identity, attributes| identity}
        agents.should include("nanite-1234")
        agents.should include("nanite-1235")
        agents.should_not include("nanite-1236")
        agents.should have(2).items
      end

      it "should fetch all nanites for a given services and tag" do
        agents = @state.nanites_for("/agent/log", "log").collect {|identity, attributes| identity}
        agents.should have(1).item
        agents.should include("nanite-1234")
      end

      it "should return an empty list when no nanites were found" do
        @state.nanites_for("/agent/log", "blog").should have(0).items
      end
    end

    context "fetching all nanites" do
      before(:each) do
        @state.clear_state
        @state['nanite-1234'] = {:status => "0.1", :services => ["/agent/log"], :tags => ["log"]}
        @state['nanite-1235'] = {:status => "0.1", :services => ["/agent/log"], :tags => ["mapreduce"]}
      end

      it "should return registered nanites" do
        @state.list_nanites.should include("nanite-1234")
        @state.list_nanites.should include("nanite-1235")
        @state.list_nanites.should have(2).items
      end

      it "should not use the keys command" do
        @state.redis.should_not_receive(:keys)
        @state.list_nanites
      end

      it "should fetch the number of available nanites" do
        @state.size.should == 2
      end
    end

  end
end
