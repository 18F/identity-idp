module Encryption
  module Encryptors
    class SmallAesEncryptor

      DELIMITER = '.'.freeze

      # "It is a riddle, wrapped in a mystery, inside an enigma; but perhaps there is a key."
      #  - Winston Churchill, https://en.wiktionary.org/wiki/a_riddle_wrapped_up_in_an_enigma
      #

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
        join_segments(plaintext, fingerprint)
      end

      def decrypt_and_test_payload(payload, cek)
        begin
          payload = cipher.decrypt(payload, cek)
        rescue OpenSSL::Cipher::CipherError => err
          raise EncryptionError, err.inspect
        end
        plaintext, fingerprint = split_into_segments(payload)
        return plaintext if Pii::Fingerprinter.verify(plaintext, fingerprint)
      end

      def join_segments(*segments)
        segments.to_msgpack
      end

      def split_into_segments(string)
        MessagePack.unpack(string)
      end
    end
  end
end
