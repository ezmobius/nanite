module Nanite

  # Represents a signed an encrypted document that can be later decrypted using
  # the right private key and whose signature can be verified using the right
  # cert.
  # This class can be used both to encrypt and sign data and to then check the
  # signature and decrypt an encrypted document.
  class EncryptedDocument
  
    # Encrypt and sign data using certificate and key pair.
    #
    # Arguments:
    #  - 'data':   Data to be encrypted
    #  - 'certs':  Recipient certificates (certificates corresponding to private
    #              keys that may be used to decrypt data)
    #  - 'cipher': Cipher used for encryption, AES 256 CBC by default
    #
    def initialize(data, certs, cipher = 'AES-256-CBC')
      cipher = OpenSSL::Cipher::Cipher.new(cipher)
      certs = [ certs ] unless certs.respond_to?(:collect)
      raw_certs = certs.collect { |c| c.raw_cert }
      @pkcs7 = OpenSSL::PKCS7.encrypt(raw_certs, data, cipher, OpenSSL::PKCS7::BINARY)
    end

    # Initialize from encrypted data.
    def self.from_data(encrypted_data)
      doc = EncryptedDocument.allocate
      doc.instance_variable_set(:@pkcs7, OpenSSL::PKCS7::PKCS7.new(encrypted_data))
      doc
    end
    
    # Encrypted data using DER format
    def encrypted_data
      @pkcs7.to_pem
    end
    
    # Decrypted data
    #
    # Arguments:
    #   - 'key':  Key used for decryption
    #   - 'cert': Certificate to use for decryption
    def decrypted_data(key, cert)
      @pkcs7.decrypt(key.raw_key, cert.raw_cert)
    end
  end
end
