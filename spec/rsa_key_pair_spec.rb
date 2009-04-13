require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::RsaKeyPair do

  before(:all) do
    @pair = Nanite::RsaKeyPair.new
  end

  it 'should create a private and a public keys' do
    @pair.has_private?.should be_true
  end

  it 'should strip out private key in to_public' do
    @pair.to_public.has_private?.should be_false
  end

  it 'should save' do
    filename = File.join(File.dirname(__FILE__), "key.pem")
    @pair.save(filename)
    File.size(filename).should be > 0
    File.delete(filename)
  end

  it 'should load' do
    filename = File.join(File.dirname(__FILE__), "key.pem")
    @pair.save(filename)
    key = Nanite::RsaKeyPair.load(filename)
    File.delete(filename)
    key.should_not be_nil
    key.data.should == @pair.data
  end

end