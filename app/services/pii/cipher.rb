module Pii
  class Cipher
    delegate :random_key, to: :cipher

    def initialize
      @cipher = OpenSSL::Cipher.new 'AES-256-CBC'
    end

    def encrypt(payload, cek)
      iv = cipher.random_iv
      cipher.encrypt
      cipher.key = cek
      cipher.iv = iv
      iv << cipher.update(payload) << cipher.final
    end

    def decrypt(payload, cek)
      prep_decrypting_cipher(payload, cek)
      decrypted_payload = cipher.update(payload[cipher.iv_len..-1]) << cipher.final
      unpack_decrypted_payload(decrypted_payload)
    end

    private

    attr_reader :cipher

    def unpack_decrypted_payload(decrypted_payload)
      padding_size = decrypted_payload.last.unpack('c').first
      decrypted_payload[0...-padding_size]
    end

    def prep_decrypting_cipher(payload, cek)
      cipher.decrypt
      cipher.padding = 0
      cipher.iv = payload[0...cipher.iv_len]
      cipher.key = cek
    end
  end
end
