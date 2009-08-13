require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite do
  describe "when ensuring a mapper exists" do
    describe "with a configured mapper proxy" do
      before(:each) do
        Nanite.instance_variable_set(:@mapper, nil)
        Nanite::MapperProxy.stub!(:instance).and_return(mock(:mapper_proxy))
      end
      
      it "should not raise an error" do
        lambda {
          Nanite.ensure_mapper
        }.should_not raise_error
      end
      
      it "should set the mapper instance variable to the mapper proxy instance" do
        Nanite.ensure_mapper
        Nanite.mapper.should == Nanite::MapperProxy.instance
      end
    end
    
    describe "when the mapper wasn't started yet" do
      before do
        Nanite.instance_variable_set(:@mapper, nil)
        Nanite::MapperProxy.stub!(:instance).and_return(nil)
      end
      
      it "should raise an error" do
        lambda {
          Nanite.ensure_mapper
        }.should raise_error(Nanite::MapperNotRunning)
      end
    end
  end
end