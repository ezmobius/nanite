module Nanite
  
  # Serializer implementation which secures messages by using
  # X.509 certificate sigining.
  class SecureSerializer
    
    # Initialize serializer, must be called prior to using it.
    #
    #  - 'identity':   Identity associated with serialized messages
    #  - 'cert':       Certificate used to sign and decrypt serialized messages
    #  - 'key':        Private key corresponding to 'cert'
    #  - 'store':      Certificate store. Exposes certificates used for
    #                  encryption and signature validation.
    #  - 'encrypt':    Whether data should be signed and encrypted ('true')
    #                  or just signed ('false'), 'true' by default.
    #
    def self.init(identity, cert, key, store, encrypt = true)
      @identity = identity
      @cert = cert
      @key = key
      @store = store
      @encrypt = encrypt
    end
    
    # Was serializer initialized?
    def self.initialized?
      @identity && @cert && @key && @store
    end

    # Serialize message and sign it using X.509 certificate
    def self.dump(obj)
      raise "Missing certificate identity" unless @identity
      raise "Missing certificate" unless @cert
      raise "Missing certificate key" unless @key
      raise "Missing certificate store" unless @store || !@encrypt
      json = obj.to_json
      if @encrypt
        certs = @store.get_recipients(obj)
        json = EncryptedDocument.new(json, certs).encrypted_data if certs
      end
      sig = Signature.new(json, @cert, @key)
      { 'id' => @identity, 'data' => json, 'signature' => sig.data, 'encrypted' => !certs.nil? }.to_json
    end
    
    # Unserialize data using certificate store
    def self.load(json)
      raise "Missing certificate store" unless @store
      raise "Missing certificate" unless @cert || !@encrypt
      raise "Missing certificate key" unless @key || !@encrypt
      data = JSON.load(json)
      sig = Signature.from_data(data['signature'])
      certs = @store.get_signer(data['id'])
      certs = [ certs ] unless certs.respond_to?(:each)
      jsn = data['data'] if certs.any? { |c| sig.match?(c) }
      if jsn && @encrypt && data['encrypted']
        jsn = EncryptedDocument.from_data(jsn).decrypted_data(@key, @cert)
      end
      JSON.load(jsn) if jsn
    end
       
  end
end
