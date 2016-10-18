module Pii
  class RsaEncryptor < Encryptor
    PADDING = OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING

    def encrypt(plaintext, private_key)
      payload = sign_and_concat(plaintext)
      cek = cipher.random_key
      join_segments(private_key.public_encrypt(cek, PADDING), cipher.encrypt(payload, cek))
    end

    def decrypt(ciphertext, private_key)
      encrypted_cek, encrypted_payload = split_into_segments(ciphertext)
      cek = private_key.private_decrypt(encrypted_cek, PADDING)
      decrypt_and_test_payload(encrypted_payload, cek)
    end

    private

    def rsa_key(pem, pw)
      Pii::KeyMaker.rsa_key(pem, pw)
    end
  end
end
