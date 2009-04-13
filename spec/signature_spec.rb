require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::Signature do
  
  include SpecHelpers

  before(:all) do
    @test_data = "Test Data"
    @cert, @key = issue_cert
    @sig = Nanite::Signature.new(@test_data, @cert, @key)
  end

  it 'should create signed data' do
    @sig.to_s.should_not be_empty
  end

  it 'should verify the signature' do
    cert2, key2 = issue_cert
  
    @sig.should be_a_match(@cert)
    @sig.should_not be_a_match(cert2)
  end

  it 'should load from serialized signature' do
    sig2 = Nanite::Signature.from_data(@sig.data)
    sig2.should_not be_nil
    sig2.should be_a_match(@cert)
  end

end