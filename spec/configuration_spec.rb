require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe Nanite::Configuration do
  describe "#file" do
    before do
      @c = Nanite::Configuration.new
    end
    
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
end