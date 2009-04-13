module Nanite

  # Build X.509 compliant distinguished names
  # Distinghuished names are used to desccribe both a certificate issuer and
  # subject.
  class DistinguishedName
    
    # Initialize distinguished name from hash
    # e.g.:
    #   { 'C'  => 'US',
    #     'ST' => 'California',
    #     'L'  => 'Santa Barbara',
    #     'O'  => 'RightScale',
    #     'OU' => 'Certification Services',
    #     'CN' => 'rightscale.com/emailAddress=cert@rightscale.com' }
    #
    def initialize(hash)
      @value = hash
    end
    
    # Conversion to OpenSSL X509 DN
    def to_x509
      if @value
        OpenSSL::X509::Name.new(@value.to_a, OpenSSL::X509::Name::OBJECT_TYPE_TEMPLATE)
      end
    end

    # Human readable form
    def to_s
      '/' + @value.to_a.collect { |p| p.join('=') }.join('/') if @value
    end
    
  end
end
