module Encryption
  module Encryptors
    class SessionEncryptor
      include Encodable

      def encrypt(plaintext)
        aes_ciphertext = AesEncryptor.new.encrypt(plaintext, aes_encryption_key)
        kms_ciphertext = KmsClient.new.encrypt(aes_ciphertext)
        encode(kms_ciphertext)
      end

      def decrypt(ciphertext)
        return deprecated_encryptor.decrypt(ciphertext) if legacy?(ciphertext)

        aes_ciphertext = KmsClient.new.decrypt(decode(ciphertext))
        aes_encryptor.decrypt(aes_ciphertext, aes_encryption_key)
      end

      private

      def legacy?(ciphertext)
        ciphertext.index('.')
      end

      def aes_encryptor
        AesEncryptor.new
      end

      def aes_encryption_key
        Figaro.env.session_encryption_key[0...32]
      end

      def deprecated_encryptor
        DeprecatedSessionEncryptor.new
      end
    end
  end
end
