module Pii
  class PasswordEncryptor < ::Pii::Encryptor
    def encrypt(plaintext, password, salt)
      cek = key_maker.generate_aes(password, salt)
      super(plaintext, cek)
    end

    def decrypt(ciphertext, password, salt)
      cek = key_maker.generate_aes(password, salt)
      super(ciphertext, cek)
    end
  end
end
