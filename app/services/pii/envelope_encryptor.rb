# digital envelope encryption model
# the format of the encrypted result is:
#
#  encrypted_random_cek + encrypted_payload
#
module Pii
  class EnvelopeEncryptor < ::Pii::Encryptor
    def encrypt(plaintext)
      payload = sign_and_concat(plaintext)
      cek = cipher.random_key
      encrypted_cek = encrypt_key(cek)
      join_segments(encrypted_cek, cipher.encrypt(payload, cek))
    end

    def decrypt(ciphertext)
      encrypted_cek, encrypted_payload = split_into_segments(ciphertext)
      cek = decrypt_key(encrypted_cek)
      decrypt_and_test_payload(encrypted_payload, cek)
    end

    private

    def encrypt_key(cek)
      raise 'must implement encrypt_key(cek) with KMS' if FeatureManagement.use_kms?
      cipher.encrypt(cek, key_maker.fetch_server_cek)
    end

    def decrypt_key(encrypted_cek)
      raise 'must implement decrypt_key(cek) with KMS' if FeatureManagement.use_kms?
      cipher.decrypt(encrypted_cek, key_maker.fetch_server_cek)
    end
  end
end
