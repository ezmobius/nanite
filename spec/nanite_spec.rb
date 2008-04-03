require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe Nanite do
  
  it "should have a checkout_dir" do
    Nanite.checkout_dir.should_not be_empty
  end
  
  describe ".configure" do
    it "should eval block in context of Nanite::Configuration" do
      Nanite.configure do
        extend Spec::Matchers
        self.should be_a_kind_of(Nanite::Configuration)
      end
    end
    
    it "should eval within the same configuration object each time" do
      config = nil
      Nanite.configure { config = self }
      Nanite.configure { self.should == config }
    end
  end
  
end