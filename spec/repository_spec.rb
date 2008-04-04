require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe Nanite::Repository do
  describe '.new' do
    it "should take one argument and set #location" do
      Nanite::Repository.new('git://where/am/i').location.should == 'git://where/am/i'
    end
  end
end