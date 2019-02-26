module Encryption
  module Encryptors
    class SessionEncryptor
      include Encodable

      def encrypt(plaintext)
        aes_ciphertext = AesEncryptor.new.encrypt(plaintext, aes_encryption_key)
        kms_ciphertext = ContextlessKmsClient.new.encrypt(aes_ciphertext)
        encode(kms_ciphertext)
      end

      def decrypt(ciphertext)
        aes_ciphertext = ContextlessKmsClient.new.decrypt(decode(ciphertext))
        aes_encryptor.decrypt(aes_ciphertext, aes_encryption_key)
      end

      private

      def aes_encryptor
        AesEncryptor.new
      end

      def aes_encryption_key
        Figaro.env.session_encryption_key[0...32]
      end
    end
  end
end
