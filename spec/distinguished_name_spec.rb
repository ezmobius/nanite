require File.join(File.dirname(__FILE__), 'spec_helper')

describe Nanite::DistinguishedName do

  before(:all) do
    test_dn = { 'C'  => 'US',
                'ST' => 'California',
                'L'  => 'Santa Barbara',
                'O'  => 'RightScale',
                'OU' => 'Certification Services',
                'CN' => 'rightscale.com/emailAddress=cert@rightscale.com' }
    @dn = Nanite::DistinguishedName.new(test_dn)
  end

  it 'should convert to string and X509 DN' do
    @dn.to_s.should_not be_nil
    @dn.to_x509.should_not be_nil
  end

  it 'should correctly encode' do
    @dn.to_s.should == @dn.to_x509.to_s
  end

end
