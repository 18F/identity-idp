module Encryption
  class KmsClient
    include Pii::Encodable

    KEY_TYPE = {
      KMS: 'KMSx',
    }.freeze

    def encrypt(plaintext)
      return encrypt_kms(plaintext) if FeatureManagement.use_kms?
      encrypt_local(plaintext)
    end

    def decrypt(ciphertext)
      return decrypt_kms(ciphertext) if FeatureManagement.use_kms? && looks_like_kms?(ciphertext)
      decrypt_local(ciphertext)
    end

    private

    def encrypt_kms(plaintext)
      ciphertext_blob = aws_client.encrypt(
        key_id: Figaro.env.aws_kms_key_id,
        plaintext: plaintext
      ).ciphertext_blob
      KEY_TYPE[:KMS] + ciphertext_blob
    end

    def decrypt_kms(ciphertext)
      kms_input = ciphertext.sub(KEY_TYPE[:KMS], '')
      aws_client.decrypt(ciphertext_blob: kms_input).plaintext
    rescue Aws::KMS::Errors::InvalidCiphertextException
      raise Pii::EncryptionError, 'Aws::KMS::Errors::InvalidCiphertextException'
    end

    def encrypt_local(plaintext)
      encryptor.encrypt(plaintext, Figaro.env.password_pepper)
    end

    def decrypt_local(ciphertext)
      encryptor.decrypt(ciphertext, Figaro.env.password_pepper)
    end

    def looks_like_kms?(ciphertext)
      ciphertext.start_with?(KEY_TYPE[:KMS])
    end

    def aws_client
      @aws_client ||= Aws::KMS::Client.new(
        instance_profile_credentials_timeout: 1, # defaults to 1 second
        instance_profile_credentials_retries: 5, # defaults to 0 retries
      )
    end

    def encryptor
      @encryptor ||= Pii::Encryptor.new
    end
  end
end
