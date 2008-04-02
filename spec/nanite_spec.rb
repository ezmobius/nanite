require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe Nanite do
  
  it "should have a checkout_dir" do
    Nanite.checkout_dir.should_not be_empty
  end
  
end