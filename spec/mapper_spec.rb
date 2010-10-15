require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::Mapper do
  include SpecHelpers

  describe "Initializing" do
    before(:each) do
      @mapper = Nanite::Mapper.new({})
    end

    it "should set the identity" do
      @mapper.identity.should_not == nil
      @mapper.identity.should =~ /mapper-.*/
    end

    it "should set the identity to a custom identity" do
      @mapper = Nanite::Mapper.new({:identity => "bob"})
      @mapper.identity.should == "mapper-bob"
    end

    it "should set the file root" do
      @mapper.options[:file_root].should == File.expand_path("#{File.dirname(__FILE__)}/../files")
    end
  end

  describe "Starting" do
    before(:each) do
      @mapper = Nanite::Mapper.new({:log_level => :debug})
      @mapper.stub!(:setup_queues)
      @mapper.stub!(:start_amqp)
    end

    it "should initialize the logger" do
      @mapper.stub!(:setup_cluster)
      run_in_em do
        @mapper.run
        Nanite::Log.logger.level.should == Logger::DEBUG
      end
    end

    it "should set the prefetch value" do
      amqp = mock("AMQP")

      mapper = Nanite::Mapper.new(:prefetch => 11)
      mapper.stub!(:setup_offline_queue)
      mapper.stub!(:setup_message_queue)
      mapper.stub!(:start_amqp)
      mapper.stub!(:setup_cluster)

      mapper.stub!(:start_amqp).and_return(amqp)
      amqp.should_receive(:prefetch).with(11)
      mapper.run
    end
  end
end
