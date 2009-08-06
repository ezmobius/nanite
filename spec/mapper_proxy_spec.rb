require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::MapperProxy do
  describe "when fetching the instance" do
    before(:each) do
      
      Nanite::MapperProxy.class_eval do
        remove_class_variable(:@@instance) if defined?(@@instance)
      end
    end
    
    it "should return nil when the instance is undefined" do
      Nanite::MapperProxy.instance.should == nil
    end
    
    it "should return the instance if defined" do
      instance = mock
      Nanite::MapperProxy.class_eval do
        @@instance = "instance"
      end
      
      Nanite::MapperProxy.instance.should_not == nil
    end
  end
end