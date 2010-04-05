require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::Certificate do
  
  include SpecHelpers

  before(:all) do
    @certificate, key = issue_cert
  end

  it 'should save' do
    filename = File.join(File.dirname(__FILE__), "cert.pem")
    @certificate.save(filename)
    File.size(filename).should be > 0
    File.delete(filename)
  end

  it 'should load' do
    filename = File.join(File.dirname(__FILE__), "cert.pem")
    @certificate.save(filename)
    cert = Nanite::Certificate.load(filename)
    File.delete(filename)
    cert.should_not be_nil
    cert.data.should == @certificate.data
  end

end
