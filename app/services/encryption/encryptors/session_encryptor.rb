module Encryption
  module Encryptors
    class SessionEncryptor
      include Encodable

      def encrypt(plaintext)
        aes_ciphertext = AesEncryptor.new.encrypt(plaintext, aes_encryption_key)
        kms_ciphertext = encrypt_with_kms(aes_ciphertext)
        encode(kms_ciphertext)
      end

      def decrypt(ciphertext)
        aes_ciphertext = KmsClient.new.decrypt(
          decode(ciphertext), 'context' => 'session-encryption'
        )
        aes_encryptor.decrypt(aes_ciphertext, aes_encryption_key)
      end

      private

      def encrypt_with_kms(ciphertext)
        if FeatureManagement.use_kms_context_for_sessions?
          KmsClient.new.encrypt(ciphertext, 'context' => 'session-encryption')
        else
          ContextlessKmsClient.new.encrypt(ciphertext)
        end
      end

      def aes_encryptor
        AesEncryptor.new
      end

      def aes_encryption_key
        Figaro.env.session_encryption_key[0...32]
      end
    end
  end
end
