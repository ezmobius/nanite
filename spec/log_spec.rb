require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::Log do
  describe "Using log without initializing it first" do
    before(:each) do
      Nanite::Log.instance_variable_set(:@logger, nil)
    end
    
    it "should use standard out for logging" do
      STDOUT.should_receive(:write).ordered
      STDOUT.should_receive(:write).with(/For your consideration/).at_least(:once).ordered
      Nanite::Log.info("For your consideration")
    end
  end

  describe "Initializing the log level" do
    it "should default to :info" do
      Nanite::Log.init
      Nanite::Log.level.should == :info
    end

    it "should raise an error if level is incorrect" do
      lambda { Nanite::Log.level = "fool" }.should raise_error
    end

    it "should succeed when using symbols" do
      [ :debug, :info, :warn, :error, :fatal ].each do |level|
        Nanite::Log.level = level
        Nanite::Log.level.should == level
      end
    end


    it "should succeed when using log levels" do
      lvls = { Logger::DEBUG => :debug,
               Logger::INFO  => :info,
               Logger::WARN  => :warn,
               Logger::ERROR => :error,
               Logger::FATAL => :fatal }
      lvls.keys.each do |level|
        Nanite::Log.level = level
        Nanite::Log.level.should == lvls[level]
      end
    end

  end
end
