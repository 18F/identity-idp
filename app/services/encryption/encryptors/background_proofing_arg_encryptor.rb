# frozen_string_literal: true

module Encryption
  module Encryptors
    class BackgroundProofingArgEncryptor
      include Encodable
      include ::NewRelic::Agent::MethodTracer

      def encrypt(plaintext)
        aes_ciphertext = AesEncryptor.new.encrypt(plaintext, aes_encryption_key)
        kms_ciphertext = kms_client.encrypt(aes_ciphertext, 'context' => 'session-encryption')
        encode(kms_ciphertext)
      end

      def decrypt(ciphertext)
        aes_ciphertext = kms_client.decrypt(
          decode(ciphertext), 'context' => 'session-encryption'
        )
        aes_encryptor.decrypt(aes_ciphertext, aes_encryption_key)
      end

      private

      def aes_encryptor
        AesEncryptor.new
      end

      def aes_encryption_key
        IdentityConfig.store.session_encryption_key[0...32]
      end

      def kms_client
        @kms_client ||= KmsClient.new(kms_key_id: IdentityConfig.store.aws_kms_session_key_id)
      end

      add_method_tracer :encrypt, "Custom/#{name}/encrypt"
      add_method_tracer :decrypt, "Custom/#{name}/decrypt"
    end
  end
end
