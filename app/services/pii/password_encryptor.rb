module Pii
  class PasswordEncryptor < ::Pii::Encryptor
    def initialize
      self.encrypted_key_maker = EncryptedKeyMaker.new
      super
    end

    def encrypt(plaintext, user_access_key)
      encrypted_key_maker.make(user_access_key)
      encrypted_c = cipher.encrypt(fingerprint_and_concat(plaintext), user_access_key.hash_e)
      join_segments(user_access_key.encryption_key, encrypted_c)
    end

    def decrypt(ciphertext, user_access_key)
      raise EncryptionError, 'ciphertext is invalid' unless sane_payload?(ciphertext)
      encrypted_d, encrypted_c = split_into_segments(ciphertext)
      hash_e = if user_access_key.unlocked?
                 user_access_key.hash_e
               else
                 encrypted_key_maker.unlock(user_access_key, encrypted_d)
               end
      decrypt_and_test_payload(encrypted_c, hash_e)
    end

    private

    attr_accessor :encrypted_key_maker
  end
end
