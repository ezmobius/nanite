require 'ostruct'
require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

describe SpecFile = Nanite::Specification::File do
  
  describe ".new" do
    it "should not require arguments" do
      lambda { SpecFile.new }.should_not raise_error
    end
    
    describe "should set attribute" do
      
      it "#path to first argument of #new" do
        @file = SpecFile.new('/tmp/test')
        @file.path.should == '/tmp/test'
      end
      
      %w( owner perms group ).each do |attr|
        it "##{attr} when sent ##{attr}=" do
          @file = SpecFile.new
          @file.send("#{attr}=", 'value')
          @file.send(attr).should == 'value'
        end
      end
    end
    
  end
  
  describe '#perms=' do
    it "should only accept strings" do
      file = SpecFile.new("/tmp/test")
      lambda { file.perms = 755 }.should raise_error ArgumentError
      lambda { file.perms = 0755 }.should raise_error ArgumentError
      lambda { file.perms = "755"}.should_not raise_error
    end
  end
  
  describe '#content' do
    before do
      @file = SpecFile.new
    end
    
    it "should set #content" do
      @file.content 'asdf'
      @file.read_content.should == 'asdf'
    end
    
    it "should accept a String, Symbol or object that responds to #read" do
      lambda { @file.content 'asdf' }.should_not raise_error
      lambda { @file.content StringIO.new('asdf') }.should_not raise_error
      lambda { @file.content :something }.should_not raise_error
    end
    
    it "should raise ArgumentError when given anything but String, Symbol or object that responds to #read" do
      lambda { @file.content 1 }.should raise_error(ArgumentError)
      lambda { @file.content Object }.should raise_error(ArgumentError)
    end
    
  end
  
  describe '#read_content' do
    before do
      @file = SpecFile.new
    end
    
    it "should return a string when #content= is given a string" do
      @file.content "asdf"
      @file.read_content.should == 'asdf'
    end
    
    it "should return value of #read when #content is given an object that responds to #read" do
      @file.content StringIO.new('test')
      @file.read_content.should == 'test'
    end
    
    it "should call a method when #content is a symbol"
    
    it "should filter #content"
  end
  
  # These tests are improved but still somewhat brittle.
  # Changing the way it's implemented (using (u/g)ids instead of names)
  # breaks the tests
  # TODO: Make these tests rely less on implementation
  describe '#update_system' do
    before do
      @file = SpecFile.new('/tmp/test')
      @mock_file = mock("file")
      @mock_stat = mock('stat')
      @mock_file.stub!(:stat).and_return(@mock_stat)
      @mock_file.stub!(:read).and_return(@current_content = 'current data')
      @mock_file.stub!(:write)
      
      ::File.should_receive(:new).with('/tmp/test').and_return(@mock_file)
    end
    
    describe "should update file permissions" do
      before { @mock_stat.stub!(:mode).and_return("100644") }
      
      it "if permissions set" do
        @mock_file.should_receive(:chmod).with(0755)
        @file.perms = "755"
        @file.update_system
      end
    
      it "unless permissions not set" do
        @mock_file.should_not_receive(:chmod)
        @file.update_system
      end
    
      it "unless permissions match current" do
        @mock_file.should_not_receive(:chmod)
        @file.perms = '644'
        @file.update_system
      end
    end
    
    describe "should update owner" do
      before do
        @mock_stat.stub!(:gid).and_return(1)
        @mock_stat.stub!(:uid).and_return(0)
        Etc.stub!(:getpwnam).and_return(OpenStruct.new(:uid => 10))
        Etc.stub!(:getpwuid).and_return(OpenStruct.new(:name => 'root'))
      end
      
      it "if owner set" do
        @mock_file.should_receive(:chown).with(10,1)
        @file.owner = 'somebody'
        @file.update_system
      end
    
      it "unless owner not set" do
        @mock_file.should_not_receive(:chown)
        @file.update_system
      end
      
      it "unless owner matches current" do
        Etc.stub!(:getpwuid).and_return(OpenStruct.new(:name => "somebody"))
        @mock_file.should_not_receive(:chown)
        @file.owner = 'somebody'
        @file.update_system
      end
    end
    
    describe "should update group" do
      before do
        @mock_stat.stub!(:gid).and_return(0)
        @mock_stat.stub!(:uid).and_return(0)
        Etc.stub!(:getgrnam).and_return(OpenStruct.new(:gid => 10))
        Etc.stub!(:getgrgid).and_return(OpenStruct.new(:name => 'root'))
      end
      
      it "if group set" do
        @mock_file.should_receive(:chown).with(0,10)
        @file.group = 'somebody'
        @file.update_system
      end
    
      it "unless group not set" do
        @mock_file.should_not_receive(:chown)
        @file.update_system
      end
      
      it "unless group matches current" do
        Etc.stub!(:getgrgid).and_return(OpenStruct.new(:name => 'somebody'))
        @mock_file.should_not_receive(:chown)
        @file.group = 'somebody'
        @file.update_system
      end
    end
    
    describe "should update content" do
      it "using data from #read_content" do
        @file.stub!(:read_content).and_return(data = "this is a test of the emergency broadcast system")
        @mock_file.should_receive(:write).with(data)
      
        @file.update_system
      end
      
      it "unless content matches" do
        @file.stub!(:read_content).and_return(@current_content.dup)
        @mock_file.should_not_receive(:write)
        @file.update_system
      end
    end
    
  end
end