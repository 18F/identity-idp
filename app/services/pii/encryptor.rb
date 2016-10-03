module Pii
  class Encryptor
    DELIMITER = '.'.freeze
    DIGEST = OpenSSL::Digest::SHA256.new.freeze

    # structure of the encrypted payload:
    #
    #  cek_encrypted_with_server_key + user_payload_encrypted_with_server_key
    #                                  v
    #          (user_private_key_pem + user_ciphertext) + user_payload_signature
    #                                  v
    #    cek_encrypted_with_user_key + pii_payload_encrypted_with_user_key
    #                                  v
    #                    PII_plaintext + PII_plaintext_signature
    #
    # The initial plaintext PII is encrypted once with a user-password-encrypted
    # private key, then again with the server-password-encrypted private key.
    # The user private key is encrypted inside the server-encrypted payload.

    def initialize
      @key_maker = Pii::KeyMaker.new
      @cipher = OpenSSL::Cipher.new 'AES-256-CBC'
    end

    def encrypt(plaintext, password)
      user_private_key_pem = key_maker.generate(password)
      user_private_key = rsa_key(user_private_key_pem, password)
      user_ciphertext = encrypt_with_key(plaintext, user_private_key)
      encrypt_with_key(
        join_segments(user_private_key_pem, user_ciphertext),
        key_maker.server_key
      )
    end

    def decrypt(ciphertext, password)
      user_payload = decrypt_with_key(ciphertext, key_maker.server_key)
      return unless user_payload
      user_private_key_pem, user_ciphertext = split_into_segments(user_payload)
      user_private_key = rsa_key(user_private_key_pem, password)
      decrypt_with_key(user_ciphertext, user_private_key)
    end

    # DHS/NIST algorithm
    def encrypt_with_key(plaintext, private_key)
      plaintext_signature = sign(plaintext, private_key)
      payload = join_segments(plaintext, plaintext_signature)
      cek = cipher.random_key
      join_segments(private_key.public_encrypt(cek), encrypt_payload(payload, cek))
    end

    # DHS/NIST algorithm
    def decrypt_with_key(ciphertext, private_key)
      encrypted_cek, encrypted_payload = split_into_segments(ciphertext)
      cek = private_key.private_decrypt(encrypted_cek)
      payload = decrypt_payload(payload: encrypted_payload, cek: cek)
      plaintext, plaintext_signature = split_into_segments(payload)
      return plaintext if sign(plaintext, private_key) == plaintext_signature
    end

    def sign(text, private_key = key_maker.server_key)
      encode(private_key.sign(DIGEST, encode(text)))
    end

    private

    attr_reader :key_maker, :cipher

    def join_segments(*segments)
      segments.map { |segment| encode(segment) }.join(DELIMITER)
    end

    def split_into_segments(string)
      string.split(DELIMITER).map { |segment| decode(segment) }
    end

    def encode(text)
      Base64.strict_encode64(text)
    end

    def decode(text)
      Base64.strict_decode64(text)
    end

    def encrypt_payload(payload, cek)
      iv = cipher.random_iv
      cipher.encrypt
      cipher.key = cek
      cipher.iv = iv
      iv << cipher.update(payload) << cipher.final
    end

    def decrypt_payload(args)
      prep_decrypting_cipher(args)
      decrypted_payload = cipher.update(args[:payload][cipher.iv_len..-1]) << cipher.final
      unpack_decrypted_payload(decrypted_payload)
    end

    def unpack_decrypted_payload(decrypted_payload)
      padding_size = decrypted_payload.last.unpack('c').first
      decrypted_payload[0...-padding_size]
    end

    def prep_decrypting_cipher(args)
      cipher.decrypt
      cipher.padding = 0
      cipher.iv = args[:payload][0...cipher.iv_len]
      cipher.key = args[:cek]
    end

    def rsa_key(pem, pw)
      Pii::KeyMaker.rsa_key(pem, pw)
    end
  end
end
