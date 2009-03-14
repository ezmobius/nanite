require File.dirname(__FILE__) + '/spec_helper'
require 'nanite/local_state'

describe "Nanite::LocalState: " do

  describe "Class" do

    it "should a Hash" do
      Nanite::LocalState.new({}).should be_kind_of(Hash)
    end

    it "should create empty hash if no hash passed in" do
      Nanite::LocalState.new.should == {}
    end

    it "should initialize hash with value passed in" do
      state = Nanite::LocalState.new({:a => 1, :b => 2, :c => 3})
      state.should == {:a => 1, :b => 2, :c => 3}
    end

  end # Class


  describe "All services" do

    it "should return empty array if no services are defined" do
      state = Nanite::LocalState.new({:f => { :foo => 1 }, :b => { :bar => 2 }})
      state.all_services.should == []
    end

    it "should return all :services values" do
      state = Nanite::LocalState.new({:f => { :foo => 1 }, :b => { :services => "b's services" }, :c => { :services => "c's services" }})
      state.all_services.should include("b's services")
      state.all_services.should include("c's services")
    end

    it "should only return one entry for each service" do
      state = Nanite::LocalState.new({:f => { :services => "services" }, :b => { :services => "services" }})
      state.all_services.size == 1
      state.all_services.should == ["services"]
    end

  end # All services


  describe "All tags" do

    it "should return empty array if no tags are defined" do
      state = Nanite::LocalState.new({:f => { :foo => 1 }, :b => { :bar => 2 }})
      state.all_tags.should == []
    end

    it "should return all :tags values" do
      state = Nanite::LocalState.new({:f => { :foo => 1 }, :b => { :tags => ["a", "b"] }, :c => { :tags => ["c", "d"] }})
      state.all_tags.should include("a")
      state.all_tags.should include("b")
      state.all_tags.should include("c")
      state.all_tags.should include("d")
    end

    it "should only return one entry for each tag" do
      state = Nanite::LocalState.new({:f => { :foo => 1 }, :b => { :tags => ["a", "b"] }, :c => { :tags => ["a", "c"] }})
      state.all_tags.size == 3
      state.all_tags.should include("a")
      state.all_tags.should include("b")
      state.all_tags.should include("c")
    end

  end # All tags

end # Nanite::LocalState
