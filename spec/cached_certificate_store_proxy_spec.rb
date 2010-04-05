require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::CachedCertificateStoreProxy do
  
  include SpecHelpers

  before(:all) do
    @signer, key = issue_cert
    @recipient, key = issue_cert
    @store = mock("Store")
    @proxy = Nanite::CachedCertificateStoreProxy.new(@store)
  end

  it 'should not raise and return nil for non existent certificates' do
    res = nil
    @store.should_receive(:get_recipients).with(nil).and_return(nil)
    lambda { res = @proxy.get_recipients(nil) }.should_not raise_error
    res.should == nil
    @store.should_receive(:get_signer).with(nil).and_return(nil)
    lambda { res = @proxy.get_signer(nil) }.should_not raise_error
    res.should == nil
  end

  it 'should return recipient certificates' do
    @store.should_receive(:get_recipients).with('anything').and_return(@recipient)
    @proxy.get_recipients('anything').should == @recipient
  end
  
  it 'should return signer certificates' do
    @store.should_receive(:get_signer).with('anything').and_return(@signer)
    @proxy.get_signer('anything').should == @signer
  end
  
end
