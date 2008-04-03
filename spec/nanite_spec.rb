require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe Nanite do
  
  it "should have a checkout_dir" do
    Nanite.checkout_dir.should_not be_empty
  end
  
  describe ".configure" do
    it "should yield a Nanite::Configuration" do
      Nanite.configure do |c|
        c.should be_a_kind_of(Nanite::Configuration)
      end
    end
    
    it "should yield the same configuration object each time" do
      config = nil
      Nanite.configure { |c| config = c }
      Nanite.configure { |c| c.should == config }
    end
  end
  
end