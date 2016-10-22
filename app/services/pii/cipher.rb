module Pii
  class Cipher
    delegate :random_key, to: :cipher

    def initialize
      @cipher = OpenSSL::Cipher.new 'aes-256-gcm'
    end

    def encrypt(plaintext, cek)
      cipher.reset
      cipher.encrypt
      cipher.key = cek
      encipher(plaintext)
    end

    def decrypt(payload, cek)
      cipher.reset
      cipher.decrypt
      cipher.key = cek
      decipher(payload)
    end

    private

    attr_reader :cipher

    def encipher(plaintext)
      iv = cipher.random_iv
      cipher.auth_data = 'PII'
      ciphertext = cipher.update(plaintext) + cipher.final
      tag = cipher.auth_tag(CipherPayload::TAG_LENGTH)
      iv + ciphertext + tag
    end

    def decipher(payload)
      unpacked_payload = CipherPayload.unpack(payload, cipher.iv_len)
      cipher.iv = unpacked_payload[0]
      cipher.auth_tag = unpacked_payload[2]
      cipher.auth_data = 'PII'
      cipher.update(unpacked_payload[1]) + cipher.final
    end
  end

  class CipherPayload
    TAG_LENGTH = 16

    def self.unpack(payload, iv_len)
      ciphertext_len = payload.length - iv_len - TAG_LENGTH
      iv = payload.byteslice(0, iv_len)
      ciphertext = payload.byteslice(iv_len, ciphertext_len)
      tag = payload.byteslice(iv_len + ciphertext_len, TAG_LENGTH)
      [iv, ciphertext, tag]
    end
  end
end
