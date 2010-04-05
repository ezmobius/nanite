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
    
    describe "with starting a mapper proxy" do
      before(:each) do
        AMQP.stub(:connect)
        MQ.stub(:new)
        Nanite.instance_variable_set(:@mapper, nil)
      end
      
      it "should generate an identity" do
        mapper_proxy = Nanite.start_mapper_proxy
        mapper_proxy.identity.should_not == nil
      end
      
      it "should use the specified identity" do
        mapper_proxy = Nanite.start_mapper_proxy(:identity => 'mymapperproxy')
        mapper_proxy.identity.should == 'mymapperproxy'
      end
      
      it "should set the @mapper instance variable" do
        mapper_proxy = Nanite.start_mapper_proxy(:identity => 'mymapperproxy')
        Nanite.instance_variable_get(:@mapper).should == mapper_proxy
      end
    end
  end
end