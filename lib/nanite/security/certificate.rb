module Nanite

  # X.509 Certificate management
  class Certificate
    
    # Underlying OpenSSL cert
    attr_accessor :raw_cert
  
    # Generate a signed X.509 certificate
    #
    # Arguments:
    #  - key: RsaKeyPair, key pair used to sign certificate
    #  - issuer: DistinguishedName, certificate issuer
    #  - subject: DistinguishedName, certificate subject
    #  - valid_for: Time in seconds before certificate expires (10 years by default)
    def initialize(key, issuer, subject, valid_for = 3600*24*365*10)
      @raw_cert = OpenSSL::X509::Certificate.new
      @raw_cert.version = 2
      @raw_cert.serial = 1
      @raw_cert.subject = subject.to_x509
      @raw_cert.issuer = issuer.to_x509
      @raw_cert.public_key = key.to_public.raw_key
      @raw_cert.not_before = Time.now
      @raw_cert.not_after = Time.now + valid_for
      @raw_cert.sign(key.raw_key, OpenSSL::Digest::SHA1.new)
    end
    
    # Load certificate from file
    def self.load(file)
      from_data(File.new(file))
    end
    
    # Initialize with raw certificate
    def self.from_data(data)
      cert = OpenSSL::X509::Certificate.new(data)
      res = Certificate.allocate
      res.instance_variable_set(:@raw_cert, cert)
      res
    end
    
    # Save certificate to file in PEM format
    def save(file)
      File.open(file, "w") do |f|
        f.write(@raw_cert.to_pem)
      end
    end
    
    # Certificate data in PEM format
    def data
      @raw_cert.to_pem
    end
    alias :to_s :data

  end
end