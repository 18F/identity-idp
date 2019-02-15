module Encryption
  class ContextlessKmsClient
    include Encodable

    KEY_TYPE = {
      KMS: 'KMSx',
    }.freeze

    def encrypt(plaintext)
      return encrypt_kms(plaintext) if FeatureManagement.use_kms?
      encrypt_local(plaintext)
    end

    def decrypt(ciphertext)
      return decrypt_kms(ciphertext) if use_kms?(ciphertext)
      decrypt_local(ciphertext)
    end

    def self.looks_like_kms?(ciphertext)
      ciphertext.start_with?(KEY_TYPE[:KMS])
    end

    private

    def use_kms?(ciphertext)
      FeatureManagement.use_kms? && self.class.looks_like_kms?(ciphertext)
    end

    def encrypt_kms(plaintext)
      if plaintext.bytesize > 4096
        encrypt_in_chunks(plaintext)
      else
        KEY_TYPE[:KMS] + encrypt_raw_kms(plaintext)
      end
    end

    # chunk plaintext into ~4096 byte chunks, but not less than 1024 bytes in a chunk if chunking.
    # we do this by counting how many chunks we have and adding one.
    # :reek:FeatureEnvy
    def encrypt_in_chunks(plaintext)
      plain_size = plaintext.bytesize
      number_chunks = plain_size / 4096
      chunk_size = plain_size / (1 + number_chunks)
      ciphertext_set = plaintext.scan(/.{1,#{chunk_size}}/m).map(&method(:encrypt_raw_kms))
      KEY_TYPE[:KMS] + ciphertext_set.map { |chunk| Base64.strict_encode64(chunk) }.to_json
    end

    def encrypt_raw_kms(plaintext)
      raise ArgumentError, 'kms plaintext exceeds 4096 bytes' if plaintext.bytesize > 4096
      aws_client.encrypt(
        key_id: Figaro.env.aws_kms_key_id,
        plaintext: plaintext,
      ).ciphertext_blob
    end

    # :reek:DuplicateMethodCall
    def decrypt_kms(ciphertext)
      raw_ciphertext = ciphertext.sub(KEY_TYPE[:KMS], '')
      if raw_ciphertext[0] == '[' && raw_ciphertext[-1] == ']'
        decrypt_chunked_kms(raw_ciphertext)
      else
        decrypt_raw_kms(raw_ciphertext)
      end
    end

    def decrypt_chunked_kms(raw_ciphertext)
      ciphertext_set = JSON.parse(raw_ciphertext).map { |chunk| Base64.strict_decode64(chunk) }
      ciphertext_set.map(&method(:decrypt_raw_kms)).join('')
    rescue JSON::ParserError, ArgumentError
      decrypt_raw_kms(raw_ciphertext)
    end

    def decrypt_raw_kms(raw_ciphertext)
      aws_client.decrypt(ciphertext_blob: raw_ciphertext).plaintext
    rescue Aws::KMS::Errors::InvalidCiphertextException
      raise EncryptionError, 'Aws::KMS::Errors::InvalidCiphertextException'
    end

    def encrypt_local(plaintext)
      encryptor.encrypt(plaintext, Figaro.env.password_pepper)
    end

    def decrypt_local(ciphertext)
      encryptor.decrypt(ciphertext, Figaro.env.password_pepper)
    end

    def aws_client
      @aws_client ||= Aws::KMS::Client.new(
        instance_profile_credentials_timeout: 1, # defaults to 1 second
        instance_profile_credentials_retries: 5, # defaults to 0 retries
      )
    end

    def encryptor
      @encryptor ||= Encryptors::AesEncryptor.new
    end
  end
end
