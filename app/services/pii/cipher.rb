module Pii
  class Cipher
    include Encodable

    def encrypt(plaintext, cek)
      self.cipher = OpenSSL::Cipher.new 'aes-256-gcm'
      cipher.encrypt
      cipher.key = cek
      encipher(plaintext)
    end

    def decrypt(payload, cek)
      self.cipher = OpenSSL::Cipher.new 'aes-256-gcm'
      cipher.decrypt
      cipher.key = cek
      decipher(payload)
    end

    private

    attr_accessor :cipher

    def encipher(plaintext)
      iv = cipher.random_iv
      cipher.auth_data = 'PII'
      ciphertext = cipher.update(plaintext) + cipher.final
      tag = cipher.auth_tag
      { iv: encode(iv), ciphertext: encode(ciphertext), tag: encode(tag) }.to_json
    end

    def decipher(payload)
      unpacked_payload = unpack_payload(payload)
      cipher.iv = iv(unpacked_payload)
      cipher.auth_tag = tag(unpacked_payload)
      cipher.auth_data = 'PII'
      try_decipher(unpacked_payload)
    end

    def try_decipher(unpacked_payload)
      cipher.update(ciphertext(unpacked_payload)) + cipher.final
    rescue OpenSSL::Cipher::CipherError => err
      raise EncryptionError, 'failed to decipher payload: ' + err.to_s
    end

    def unpack_payload(payload)
      JSON.parse(payload, symbolize_names: true)
    rescue StandardError => err
      raise Pii::EncryptionError, "Unable to parse encrypted payload. #{err.inspect}"
    end

    def iv(unpacked_payload)
      decode(unpacked_payload[:iv])
    end

    def tag(unpacked_payload)
      decode(unpacked_payload[:tag])
    end

    def ciphertext(unpacked_payload)
      decode(unpacked_payload[:ciphertext])
    end
  end
end
