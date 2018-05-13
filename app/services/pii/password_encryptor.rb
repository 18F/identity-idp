module Pii
  class PasswordEncryptor < ::Pii::Encryptor
    # TODO: Refactor this class to be initialized with a user access key :reek:FeatureEnvy
    def encrypt(plaintext, user_access_key)
      user_access_key.build unless user_access_key.built?
      encrypted_c = cipher.encrypt(fingerprint_and_concat(plaintext), user_access_key.cek)
      join_segments(user_access_key.encryption_key, encrypted_c)
    end

    def decrypt(ciphertext, user_access_key)
      raise EncryptionError, 'ciphertext is invalid' unless sane_payload?(ciphertext)
      encryption_key, encrypted_c = split_into_segments(ciphertext)
      user_access_key.unlock(encryption_key) unless user_access_key.unlocked?
      decrypt_and_test_payload(encrypted_c, user_access_key.cek)
    end
  end
end
