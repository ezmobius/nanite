$TESTING=true
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'spec'
require 'nanite'

module SpecHelpers

  # Initialize logger so it writes to file instead of STDOUT
  Nanite::Log.init('test', File.join(File.dirname(__FILE__)))

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

  def run_in_em(stop_event_loop = true)
    EM.run do
      yield
      EM.stop_event_loop if stop_event_loop
    end
  end
  
end  