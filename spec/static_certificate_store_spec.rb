require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::StaticCertificateStore do
  
  include SpecHelpers

  before(:all) do
    @signer, key = issue_cert
    @recipient, key = issue_cert
    @cert, @key = issue_cert
    @store = Nanite::StaticCertificateStore.new(@signer, @recipient)
  end

  it 'should not raise when passed nil objects' do
    res = nil
    lambda { res = @store.get_signer(nil) }.should_not raise_error
    res.should == [ @signer ]
    lambda { res = @store.get_recipients(nil) }.should_not raise_error
    res.should == [ @recipient ]
  end

  it 'should return signer certificates' do
    @store.get_signer('anything').should == [ @signer ]
  end

  it 'should return recipient certificates' do
    @store.get_recipients('anything').should == [ @recipient ]
  end
  
end