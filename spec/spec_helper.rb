$TESTING=true
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'spec'
require 'nanite'

module SpecHelpers
  
  # Create test certificate
  def issue_cert
    test_dn = { 'C'  => 'US',
                'ST' => 'California',
                'L'  => 'Santa Barbara',
                'O'  => 'Nanite',
                'OU' => 'Certification Services',
                'CN' => 'Nanite test' }
    dn = Nanite::DistinguishedName.new(test_dn)
    key = Nanite::RsaKeyPair.new
    [ Nanite::Certificate.new(key, dn, dn), key ]
  end

end  