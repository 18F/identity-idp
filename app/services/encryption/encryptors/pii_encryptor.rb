module Encryption
  module Encryptors
    class PiiEncryptor
      include Pii::Encodable

      def initialize(password:, salt:, cost: nil)
        cost ||= Figaro.env.scrypt_cost
        @aes_cipher = Pii::Cipher.new
        @kms_client = KmsClient.new
        @scrypt_password_digest = build_scrypt_password(password, salt, cost).digest
      end

      def encrypt(plaintext)
        aes_encrypted_ciphertext = aes_cipher.encrypt(plaintext, aes_encryption_key)
        kms_encrypted_ciphertext = kms_client.encrypt(aes_encrypted_ciphertext)
        encode(kms_encrypted_ciphertext)
      end

      def decrypt(ciphertext)
        raise Pii::EncryptionError, 'ciphertext invalid' unless valid_base64_encoding?(ciphertext)
        decoded_ciphertext = decode(ciphertext)
        aes_encrypted_ciphertext = kms_client.decrypt(decoded_ciphertext)
        aes_cipher.decrypt(aes_encrypted_ciphertext, aes_encryption_key)
      end

      private

      attr_reader :aes_cipher, :kms_client, :scrypt_password_digest

      def build_scrypt_password(password, salt, cost)
        scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(salt)
        scrypted = SCrypt::Engine.hash_secret password, scrypt_salt, 32
        SCrypt::Password.new(scrypted)
      end

      def aes_encryption_key
        scrypt_password_digest[0...32]
      end
    end
  end
end
