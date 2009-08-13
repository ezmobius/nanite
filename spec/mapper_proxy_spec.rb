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

  describe "when pushing a message" do
    before do
      AMQP.stub!(:connect)
      MQ.stub!(:new)
      Nanite::MapperProxy.new('mapperproxy', {})
      @instance = Nanite::MapperProxy.instance
      @fanout = stub(:fanout, :publish => true)
      @instance.amqp.stub!(:fanout).and_return(@fanout)
    end
    
    it "should raise an error if mapper proxy is not initialized" do
      lambda {
        @instance.stub!(:identity).and_return nil
        @instance.push('/welcome/aboard', 'iZac')
      }.should raise_error("Mapper proxy not initialized")
    end
    
    it "should set correct attributes on the push message" do
      @fanout.should_receive(:publish).with do |push|
        push = @instance.serializer.load(push)
        push.token.should_not == nil
        push.persistent.should_not == true
        push.from.should == 'mapperproxy'
      end
      
      @instance.push('/welcome/aboard', 'iZac')
    end
    
    it "should mark the message as persistent when the option is specified on the parameter" do
      @fanout.should_receive(:publish).with do |push|
        push = @instance.serializer.load(push)
        push.persistent.should == true
      end
      
      @instance.push('/welcome/aboard', 'iZac', :persistent => true)
    end
    
    it "should mark the message as persistent when the option is set globally" do
      @instance.options[:persistent] = true
      @fanout.should_receive(:publish).with do |push|
        push = @instance.serializer.load(push)
        push.persistent.should == true
      end
      
      @instance.push('/welcome/aboard', 'iZac')
    end
  end
end