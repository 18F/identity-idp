module Pii
  class KeyMaker
    attr_reader :server_key

    def initialize
      @cipher = OpenSSL::Cipher.new 'AES-256-CBC'
      @server_key = server_private_key
    end

    def generate(passphrase)
      key = OpenSSL::PKey::RSA.new(2048)
      cipher.encrypt
      key.to_pem(cipher, passphrase)
    end

    def self.rsa_key(pem, passphrase)
      OpenSSL::PKey::RSA.new(pem, passphrase)
    end

    private

    attr_reader :cipher

    def server_private_key
      self.class.rsa_key(server_private_key_pem, Figaro.env.pii_passphrase)
    end

    def server_private_key_pem
      raise 'Must implement private_key_pem in production' if Rails.env.production?
      File.read(Rails.root + 'keys/pii.key.enc')
    end
  end
end
