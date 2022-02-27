module Encryption
  module Encryptors
    class SmallSessionEncryptor
      include ::NewRelic::Agent::MethodTracer

      def encrypt(plaintext)
        aes_ciphertext = SmallAesEncryptor.new.encrypt(plaintext, aes_encryption_key)
        SmallKmsClient.new.encrypt(aes_ciphertext, 'context' => 'session-encryption')
      end

      def decrypt(ciphertext)
        aes_ciphertext = SmallKmsClient.new.decrypt(
          ciphertext, 'context' => 'session-encryption'
        )
        aes_encryptor.decrypt(aes_ciphertext, aes_encryption_key)
      end

      private

      def aes_encryptor
        SmallAesEncryptor.new
      end

      def aes_encryption_key
        IdentityConfig.store.session_encryption_key[0...32]
      end

      add_method_tracer :encrypt, "Custom/#{name}/encrypt"
      add_method_tracer :decrypt, "Custom/#{name}/decrypt"
    end
  end
end
