module Pii
  class Encryptor
    def encrypt(plaintext)
      encode(plaintext)
    end

    def decrypt(ciphertext)
      decode(ciphertext)
    end

    private

    def encode(text)
      Base64.strict_encode64(text)
    end

    def decode(text)
      Base64.strict_decode64(text)
    end
  end
end
