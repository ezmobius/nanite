require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe Nanite::Configuration do
  before do
    @c = Nanite::Configuration.new
  end
  
  describe "#file" do
    it "should instantiate a File" do
      (@c.file :mine, '/etc/hosts').should be_a_kind_of Nanite::Specification::File
    end
    
    it "should yield the new File object to a block" do
      @c.file :test, 'asdf' do |f|
        f.should be_a_kind_of Nanite::Specification::File
      end
    end
    
    it "should return the same object when called with the same symbol" do
      f = @c.file :test, 'test'
      (@c.file :test).should == f
    end
  end
    
  it "#repository_root should be writeable" do
    lambda { @c.repository_root = 'test' }.should_not raise_error
  end
    
  describe "#repository" do
    it "should be prefixed by #repository_root if no ://" do
      Nanite::Repository.should_receive(:new).with('testasdf')
      @c.repository_root = 'test'
      @c.add_repository('asdf')
    end
    
    it "should pass name directly if name includes ://" do
      Nanite::Repository.should_receive(:new).with('git://asdf')
      @c.repository_root = 'test'
      @c.add_repository 'git://asdf'
    end
  end
end