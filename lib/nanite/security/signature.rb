module Nanite

  # Signature that can be validated against certificates
  class Signature
    
    FLAGS = OpenSSL::PKCS7::NOCERTS || OpenSSL::PKCS7::BINARY || OpenSSL::PKCS7::NOATTR || OpenSSL::PKCS7::NOSMIMECAP || OpenSSL::PKCS7::DETACH

    # Create signature using certificate and key pair.
    #
    # Arguments:
    #  - 'data': Data to be signed
    #  - 'cert': Certificate used for signature
    #  - 'key':  RsaKeyPair used for signature
    #
    def initialize(data, cert, key)
      @p7 = OpenSSL::PKCS7.sign(cert.raw_cert, key.raw_key, data, [], FLAGS)
      @store = OpenSSL::X509::Store.new
    end
    
    # Load signature previously serialized via 'data'
    def self.from_data(data)
      sig = Signature.allocate
      sig.instance_variable_set(:@p7, OpenSSL::PKCS7::PKCS7.new(data))
      sig.instance_variable_set(:@store, OpenSSL::X509::Store.new)
      sig
    end

    # 'true' if signature was created using given cert, 'false' otherwise
    def match?(cert)
      @p7.verify([cert.raw_cert], @store, nil, OpenSSL::PKCS7::NOVERIFY)
    end

    # Signature in PEM format
    def data
      @p7.to_pem
    end
    alias :to_s :data

  end
end
