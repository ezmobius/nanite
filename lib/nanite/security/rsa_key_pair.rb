module Nanite

  # Allows generating RSA key pairs and extracting public key component
  # Note: Creating a RSA key pair can take a fair amount of time (seconds)
  class RsaKeyPair
    
    DEFAULT_LENGTH = 2048

    # Underlying OpenSSL keys
    attr_reader :raw_key

    # Create new RSA key pair using 'length' bits
    def initialize(length = DEFAULT_LENGTH)
      @raw_key = OpenSSL::PKey::RSA.generate(length)
    end

    # Does key pair include private key?
    def has_private?
      raw_key.private?
    end
    
    # New RsaKeyPair instance with identical public key but no private key
    def to_public
      RsaKeyPair.from_data(raw_key.public_key.to_pem)
    end
    
    # Key material in PEM format
    def data
      raw_key.to_pem
    end
    alias :to_s :data
    
    # Load key pair previously serialized via 'data'    
    def self.from_data(data)
      res = RsaKeyPair.allocate
      res.instance_variable_set(:@raw_key, OpenSSL::PKey::RSA.new(data)) 
      res
    end

    # Load key from file
    def self.load(file)
      from_data(File.read(file))
    end
    
    # Save key to file in PEM format
    def save(file)
      File.open(file, "w") do |f|
        f.write(@raw_key.to_pem)
      end
    end

  end
end
