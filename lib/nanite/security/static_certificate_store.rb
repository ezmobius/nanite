module Nanite

  # Simple certificate store, serves a static set of certificates.
  class StaticCertificateStore
    
    # Initialize store:
    #
    #  - Signer certificates are used when loading data to check the digital
    #    signature. The signature associated with the serialized data needs
    #    to match with one of the signer certificates for loading to succeed.
    #
    #  - Recipient certificates are used when serializing data for encryption.
    #    Loading the data can only be done through serializers that have been
    #    initialized with a certificate that's in the recipient certificates if
    #    encryption is enabled.
    #
    def initialize(signer_certs, recipients_certs)
      signer_certs = [ signer_certs ] unless signer_certs.respond_to?(:each)
      @signer_certs = signer_certs 
      recipients_certs = [ recipients_certs ] unless recipients_certs.respond_to?(:each)
      @recipients_certs = recipients_certs
    end
    
    # Retrieve signer certificate for given id
    def get_signer(identity)
      @signer_certs
    end

    # Recipient certificate(s) that will be able to decrypt the serialized data
    def get_recipients(obj)
      @recipients_certs
    end
    
  end  
end
