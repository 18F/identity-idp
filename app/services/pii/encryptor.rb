module Pii
  class Encryptor
    DELIMITER = '.'.freeze
    DIGEST = OpenSSL::Digest::SHA256.new.freeze

    # "It is a riddle, wrapped in a mystery, inside an enigma; but perhaps there is a key."
    #  - Winston Churchill, https://en.wiktionary.org/wiki/a_riddle_wrapped_up_in_an_enigma
    #

    def initialize(key_maker = Pii::KeyMaker.new)
      @key_maker = key_maker
      @cipher = Pii::Cipher.new
    end

    def encrypt(plaintext, cek)
      payload = sign_and_concat(plaintext)
      encode(cipher.encrypt(payload, cek))
    end

    def decrypt(ciphertext, cek)
      decrypt_and_test_payload(decode(ciphertext), cek)
    end

    def sign(text)
      signing_key = key_maker.signing_key
      encode(signing_key.sign(DIGEST, encode(text)))
    end

    def verify(text, signature)
      signing_key = key_maker.signing_key
      signing_key.verify(DIGEST, decode(signature), encode(text))
    end

    private

    attr_reader :key_maker, :cipher

    def sign_and_concat(plaintext)
      plaintext_signature = sign(plaintext)
      join_segments(plaintext, plaintext_signature)
    end

    def decrypt_and_test_payload(payload, cek)
      payload = cipher.decrypt(payload, cek)
      raise EncryptionError unless sane_payload?(payload)
      plaintext, plaintext_signature = split_into_segments(payload)
      return plaintext if verify(plaintext, plaintext_signature)
    end

    def sane_payload?(payload)
      payload =~ %r{^[A-Za-z0-9\/\=#{DELIMITER}]+$}
    end

    def join_segments(*segments)
      segments.map { |segment| encode(segment) }.join(DELIMITER)
    end

    def split_into_segments(string)
      string.split(DELIMITER).map { |segment| decode(segment) }
    end

    def encode(text)
      Base64.strict_encode64(text)
    end

    def decode(text)
      Base64.strict_decode64(text)
    end
  end
end
