require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::MapperProxy do
  describe "when fetching the instance" do
    before do
      Nanite::MapperProxy.class_eval do
        if class_variable_defined?(:@@instance)
          remove_class_variable(:@@instance) 
        end
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
  
  describe "when requesting a message" do
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
        @instance.request('/welcome/aboard', 'iZac'){|response|}
      }.should raise_error("Mapper proxy not initialized")
    end
    
    it "should create a request object" do
      @fanout.should_receive(:publish).with do |request|
        request = @instance.serializer.load(request)
        request.class.should == Nanite::Request
      end
      
      @instance.request('/welcome/aboard', 'iZac'){|response|}
    end
    
    it "should set correct attributes on the request message" do
      @fanout.should_receive(:publish).with do |request|
        request = @instance.serializer.load(request)
        request.token.should_not == nil
        request.persistent.should_not == true
        request.from.should == 'mapperproxy'
      end
      
      @instance.request('/welcome/aboard', 'iZac'){|response|}
    end
    
    it "should mark the message as persistent when the option is specified on the parameter" do
      @fanout.should_receive(:publish).with do |request|
        request = @instance.serializer.load(request)
        request.persistent.should == true
      end
      
      @instance.request('/welcome/aboard', 'iZac', :persistent => true){|response|}
    end
    
    it "should set the correct target if specified" do
      @fanout.should_receive(:publish).with do |request|
        request = @instance.serializer.load(request)
        request.target.should == 'my-target'
      end
      
      @instance.request('/welcome/aboard', 'iZac', :target => 'my-target'){|response|}
    end
    
    it "should mark the message as persistent when the option is set globally" do
      @instance.options[:persistent] = true
      @fanout.should_receive(:publish).with do |request|
        request = @instance.serializer.load(request)
        request.persistent.should == true
      end
      
      @instance.request('/welcome/aboard', 'iZac'){|response|}
    end
    
    it "should store the intermediate handler" do
      intermediate = lambda {}
      Nanite::Identity.stub!(:generate).and_return('abc')
      @fanout.stub!(:fanout)
      
      @instance.request('/welcome/aboard', 'iZac', :target => 'my-target', :intermediate_handler => intermediate ){|response|}
      
      @instance.pending_requests['abc'][:intermediate_handler].should == intermediate
    end
    
    it "should store the result handler" do
      result_handler = lambda {}
      Nanite::Identity.stub!(:generate).and_return('abc')
      @fanout.stub!(:fanout)
      
      @instance.request('/welcome/aboard', 'iZac',{}, &result_handler)
      
      @instance.pending_requests['abc'][:result_handler].should == result_handler
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
    
    it "should create a push object" do
      @fanout.should_receive(:publish).with do |push|
        push = @instance.serializer.load(push)
        push.class.should == Nanite::Push
      end
      
      @instance.push('/welcome/aboard', 'iZac')
    end
    
    it "should set the correct target if specified" do
      @fanout.should_receive(:publish).with do |push|
        push = @instance.serializer.load(push)
        push.target.should == 'my-target'
      end
      
      @instance.push('/welcome/aboard', 'iZac', :target => 'my-target')
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
  
  describe "when handling results" do
    before(:each) do
      AMQP.stub!(:connect)
      MQ.stub!(:new)
      Nanite::MapperProxy.new('mapperproxy', {})
      @instance = Nanite::MapperProxy.instance 
      @fanout = stub(:fanout, :publish => true)
      @instance.amqp.stub!(:fanout).and_return(@fanout)
      @payload = {:payload => ['nanite', 'eventmachine', 'rabbitmq']}
    end
    
    describe 'final results' do
      before do
        @response = mock("Response")
        @response.should_receive(:token).and_return("test_token")
        @response.should_receive(:results).twice.and_return({:payload => ['nanite', 'eventmachine', 'rabbitmq']})
        result_handler = lambda {}
        @fanout.stub!(:fanout)
        @instance.pending_requests["test_token"] = {:result_handler => Proc.new{ @response.results} }
        @instance.request('/welcome/aboard', 'iZac',{}, &result_handler)
      end
      it "should return the provided payload through the result handler" do
         @instance.handle_result(@response).should == @payload
      end
    end
    
    describe 'intermediate results' do
      before do
        @response = mock("Response")
        @response.should_receive(:token).and_return("test_token_2")
        @response.should_receive(:results).twice.and_return({:payload => ['nanite', 'eventmachine', 'rabbitmq']})
        result_handler = lambda {}
        @fanout.stub!(:fanout)
        
        int_handler = Proc.new{ @response.results.merge(:time => Time.now)}
      
        @instance.pending_requests["test_token_2"] = {:result_handler => Proc.new{ @response.results}, 
                                                      :intermediate_handler => int_handler}
        @instance.request('/welcome/aboard', 'iZac', :intermediate_handler => int_handler, &result_handler)
      end
      it "should provide a Hash for intermediate results" do
        @instance.handle_intermediate_result(@response).should be_kind_of(Hash)
      end
    end
  end
end