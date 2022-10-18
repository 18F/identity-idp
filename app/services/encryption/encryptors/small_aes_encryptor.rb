module Encryption
  module Encryptors
    class SmallAesEncryptor
      def initialize
        self.cipher = SmallAesCipher.new
      end

      def encrypt(plaintext, cek)
        payload = fingerprint_and_concat(plaintext)
        cipher.encrypt(payload, cek)
      end

      def decrypt(ciphertext, cek)
        decrypt_and_test_payload(ciphertext, cek)
      end

      private

      attr_accessor :cipher

      def fingerprint_and_concat(plaintext)
        fingerprint = Pii::Fingerprinter.fingerprint(plaintext)
        [plaintext, fingerprint].to_msgpack
      end

      def decrypt_and_test_payload(payload, cek)
        begin
          plaintext, fingerprint = MessagePack.unpack(cipher.decrypt(payload, cek))
        rescue OpenSSL::Cipher::CipherError, MessagePack::MalformedFormatError => err
          raise EncryptionError, err.inspect
        end
        return plaintext if Pii::Fingerprinter.verify(plaintext, fingerprint)
      end
    end
  end
end
