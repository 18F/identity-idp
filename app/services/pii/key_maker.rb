module Pii
  class KeyMaker
    attr_reader :signing_key

    def initialize(iterations = 100_000)
      @cipher = OpenSSL::Cipher.new 'AES-256-CBC'
      @signing_key = server_signing_key
      @pbkdf2_iterations = iterations
      @digest = OpenSSL::Digest::SHA256.new
    end

    def generate_rsa(passphrase)
      key = OpenSSL::PKey::RSA.new(2048)
      cipher.encrypt
      key.to_pem(cipher, passphrase)
    end

    def generate_aes(passphrase, salt)
      pepper = Figaro.env.password_pepper
      text = passphrase + pepper
      digest.class.hexdigest(
        OpenSSL::PKCS5.pbkdf2_hmac(text, salt, pbkdf2_iterations, digest.digest_length, digest)
      )
    end

    def fetch_server_cek
      raise 'Must implement fetch_server_cek with KMS' if FeatureManagement.use_kms?
      Figaro.env.pii_server_cek
    end

    def self.rsa_key(pem, passphrase)
      OpenSSL::PKey::RSA.new(pem, passphrase)
    end

    private

    attr_reader :cipher, :pbkdf2_iterations, :digest

    def server_signing_key
      self.class.rsa_key(server_signing_key_pem, Figaro.env.pii_signing_passphrase)
    end

    def server_signing_key_pem
      raise 'Must implement server_signing_key_pem with KMS' if FeatureManagement.use_kms?
      File.read(Rails.root + 'keys/pii_signing.key.enc')
    end
  end
end
