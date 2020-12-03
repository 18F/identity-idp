module Encryption
  module Encryptors
    class SessionEncryptor
      include Encodable
      include ::NewRelic::Agent::MethodTracer
      add_method_tracer :encrypt, "Custom/#{name}/encrypt"
      add_method_tracer :decrypt, "Custom/#{name}/decrypt"

      def encrypt(plaintext)
        aes_ciphertext = AesEncryptor.new.encrypt(plaintext, aes_encryption_key)
        kms_ciphertext = KmsClient.new.encrypt(aes_ciphertext, 'context' => 'session-encryption')
        encode(kms_ciphertext)
      end

      def decrypt(ciphertext)
        aes_ciphertext = KmsClient.new.decrypt(
          decode(ciphertext), 'context' => 'session-encryption'
        )
        aes_encryptor.decrypt(aes_ciphertext, aes_encryption_key)
      end

      private

      def aes_encryptor
        AesEncryptor.new
      end

      def aes_encryption_key
        AppConfig.env.session_encryption_key[0...32]
      end
    end
  end
end
