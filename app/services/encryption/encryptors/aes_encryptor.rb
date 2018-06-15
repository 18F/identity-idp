module Encryption
  module Encryptors
    class AesEncryptor
      include Encodable

      DELIMITER = '.'.freeze

      # "It is a riddle, wrapped in a mystery, inside an enigma; but perhaps there is a key."
      #  - Winston Churchill, https://en.wiktionary.org/wiki/a_riddle_wrapped_up_in_an_enigma
      #

      def initialize
        self.cipher = AesCipher.new
      end

      def encrypt(plaintext, cek)
        payload = fingerprint_and_concat(plaintext)
        encode(cipher.encrypt(payload, cek))
      end

      def decrypt(ciphertext, cek)
        raise EncryptionError, 'ciphertext is invalid' unless sane_payload?(ciphertext)
        decrypt_and_test_payload(decode(ciphertext), cek)
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
        raise EncryptionError, 'payload is invalid' unless sane_payload?(payload)
        plaintext, fingerprint = split_into_segments(payload)
        return plaintext if Pii::Fingerprinter.verify(plaintext, fingerprint)
      end

      def sane_payload?(payload)
        payload.split(DELIMITER).each do |segment|
          return false unless valid_base64_encoding?(segment)
        end
      end

      def join_segments(*segments)
        segments.map { |segment| encode(segment) }.join(DELIMITER)
      end

      def split_into_segments(string)
        string.split(DELIMITER).map { |segment| decode(segment) }
      end
    end
  end
end
