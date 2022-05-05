module Encryption
  class AesCipher
    include Encodable

    def encrypt(plaintext, cek)
      self.cipher = self.class.encryption_cipher
      # The key length for the AES-256-GCM cipher is fixed at 128 bits, or 32
      # characters. Starting with Ruby 2.4, an expection is thrown if you try to
      # set a key longer than 32 characters, which is what we have been doing
      # all along. In prior versions of Ruby, the key was silently truncated.
      cipher.key = cek[0..31]
      encipher(plaintext)
    end

    def decrypt(payload, cek)
      self.cipher = OpenSSL::Cipher.new 'aes-256-gcm'
      cipher.decrypt
      cipher.key = cek[0..31]
      decipher(payload)
    end

    def self.encryption_cipher
      OpenSSL::Cipher.new('aes-256-gcm').encrypt
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
    rescue StandardError
      raise EncryptionError, 'Unable to parse encrypted payload'
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
