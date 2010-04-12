require File.join(File.dirname(__FILE__), 'spec_helper')
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


  describe "Nanites lookup" do

    it "should find services matching the service criteria if no tags criteria is specified" do
      state = Nanite::LocalState.new({:a => { :services => "a's services" }, :b => { :services => "b's services" }})
      state.nanites_for("b's services").should == [[:b, {:services => "b's services"}]]
    end

    it "should find all services matching the service criteria if no tags criteria is specified" do
      state = Nanite::LocalState.new({:a => { :services => "services" }, :b => { :services => "services" }, :c => { :services => "other services" }})
      state.nanites_for("services").should include([:a, {:services => "services"}])
      state.nanites_for("services").should include([:b, {:services => "services"}])
    end

    it "should only services matching the service criteria that also match the tags criteria" do
      state = Nanite::LocalState.new({:a => { :services => "a's services", :tags => ["a_1", "a_2"] }, :b => { :services => "b's services", :tags => ["b_1", "b_2"] }})
      state.nanites_for("b's services").should == [[:b, {:tags=>["b_1", "b_2"], :services=>"b's services"}]]
    end
    
    it "should find all services with matching tags even if the tag order is different" do
      state = Nanite::LocalState.new({:a => { :services => "services", :tags => ["a_1", "a_2"] }, :b => { :services => "services", :tags => ["a_2", "a_1"] }})
      state.nanites_for("services", ['a_1', 'a_2']).should include([:a, {:tags=>["a_1", "a_2"], :services=>"services"}])
      state.nanites_for("services", ['a_1', 'a_2']).should include([:b, {:tags=>["a_2", "a_1"], :services=>"services"}])
    end

    it "should also return all tags for services matching the service criteria that also match a single tags criterium" do
      state = Nanite::LocalState.new({:a => { :services => "services", :tags => ["t_1", "t_2"] }})
      state.nanites_for("services", ["t_1"]).should == [[:a, {:tags=>["t_1", "t_2"], :services=>"services"}]]
    end

    it "should return services matching the service criteria and also match the tags criterium" do
      state = Nanite::LocalState.new({:a => { :services => "a's services", :tags => ["a_1", "a_2"] }, :b => { :services => "b's services", :tags => ["b_1", "b_2"] }})
      state.nanites_for("b's services", ["b_1"]).should == [[:b, {:tags=>["b_1", "b_2"], :services=>"b's services"}]]
    end

    it "should ignore services matching the service criteria and but not the tags criteria" do
      state = Nanite::LocalState.new({:a => { :services => "services", :tags => ["t_1", "t_2"] }, :b => { :services => "services", :tags => ["t_3", "t_4"] }})
      state.nanites_for("services", ["t_1"]).should == [[:a, {:services => "services", :tags => ["t_1", "t_2"]}]]
    end

    it "should lookup services matching the service criteria and and any of the tags criteria" do
      state = Nanite::LocalState.new({'a' => { :services => "services", :tags => ["t_1", "t_2"] }, 'b' => { :services => "services", :tags => ["t_2", "t_3"] }})
      state.nanites_for("services", ["t_1", "t_3"]).sort.should == [['a', {:services => "services", :tags => ["t_1", "t_2"]}], ['b', {:services => "services", :tags => ["t_2", "t_3"]}]]
    end

  end # Nanites lookup

  describe "Updating a Nanite's status" do
    it "should set the status for the nanite" do
      state = Nanite::LocalState.new('a' => { :services => "service" })
      state.update_status('a', 0.1)
      state['a'][:status].should == 0.1
    end
    
    it "should store the timestamp for the nanite" do
      state = Nanite::LocalState.new('a' => { :services => "service" })
      state.update_status('a', 0.1)
      state['a'][:timestamp].should be_close(Time.now.utc.to_i, 1)
    end
  end
end # Nanite::LocalState
