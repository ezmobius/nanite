require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::Log do
  describe "Using log without initializing it first" do
    before(:each) do
      Nanite::Log.instance_variable_set(:@logger, nil)
    end
    
    it "should use standard out for logging" do
      STDOUT.should_receive(:write) do |arg|
        arg.include?("For your consideration").should == true
      end
      Nanite::Log.info("For your consideration")
    end
  end
end