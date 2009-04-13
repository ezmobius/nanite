require File.join(File.dirname(__FILE__), 'spec_helper')

module Nanite
  
  # Add the ability to compare pings for test purposes
  class Ping
    def ==(other)
      @status == other.status && @identity == other.identity
    end
  end
  
end

describe Nanite::SecureSerializer do
  
  include SpecHelpers

  before(:all) do
    @certificate, @key = issue_cert
    @store = Nanite::StaticCertificateStore.new(@certificate, @certificate)
    @identity = "id"
    @data = Nanite::Ping.new("Test", 0.5)
  end
  
  it 'should raise when not initialized' do
    lambda { Nanite::SecureSerializer.dump(@data) }.should raise_error
  end

  it 'should deserialize signed data' do
    Nanite::SecureSerializer.init(@identity, @certificate, @key, @store, false)
    data = Nanite::SecureSerializer.dump(@data)
    Nanite::SecureSerializer.load(data).should == @data
  end
  
  it 'should deserialize encrypted data' do
    Nanite::SecureSerializer.init(@identity, @certificate, @key, @store, true)
    data = Nanite::SecureSerializer.dump(@data)
    Nanite::SecureSerializer.load(data).should == @data
  end

end