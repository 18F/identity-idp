class EncryptedKeyMaker
  include Pii::Encodable

  KEY_TYPE = {
    KMS: 'KMSx',
  }.freeze

  # Creates an encrypted encryption key.
  #
  # @param user_access_key [UserAccessKey]
  # @return [UserAccessKey]
  #
  def make(user_access_key)
    unless user_access_key.is_a? UserAccessKey
      raise "user_access_key must be a UserAccessKey - you passed #{user_access_key}"
    end
    if FeatureManagement.use_kms?
      make_kms(user_access_key)
    else
      make_local(user_access_key)
    end
  end

  # Given encrypted key D, return the hash E for decrypting PII.
  # @param user_access_key [UserAccessKey]
  # @param encryption_key [String] stored on User model
  # @return hash_E [String]
  def unlock(user_access_key, encryption_key)
    unless user_access_key.is_a? UserAccessKey
      raise Pii::EncryptionError, 'user_access_key must be a UserAccessKey'
    end
    unless valid_base64_encoding?(encryption_key)
      raise Pii::EncryptionError, 'cannot use invalid base64 encryption_key'
    end
    unlock_key(user_access_key, encryption_key)
  end

  private

  def unlock_key(user_access_key, encryption_key)
    if FeatureManagement.use_kms? && looks_like_kms?(user_access_key, encryption_key)
      unlock_kms(user_access_key, encryption_key)
    else
      unlock_local(user_access_key, encryption_key)
    end
  end

  def build_user_access_key(user_access_key, encrypted_key)
    user_access_key.store_encrypted_key(encrypted_key)
    user_access_key
  end

  def make_kms(user_access_key)
    encrypted_key = aws_client.encrypt(
      key_id: Figaro.env.aws_kms_key_id,
      plaintext: user_access_key.random_r
    ).ciphertext_blob
    build_user_access_key(user_access_key, KEY_TYPE[:KMS] + encrypted_key)
  end

  def unlock_kms(user_access_key, encryption_key)
    ciphertext = user_access_key.xor(decode(encryption_key)).sub(KEY_TYPE[:KMS], '')
    user_access_key.unlock(aws_client.decrypt(ciphertext_blob: ciphertext).plaintext)
  rescue Aws::KMS::Errors::InvalidCiphertextException
    raise Pii::EncryptionError, 'Aws::KMS::Errors::InvalidCiphertextException'
  end

  def make_local(user_access_key)
    encrypted_key = encryptor.encrypt(user_access_key.random_r, Figaro.env.password_pepper)
    build_user_access_key(user_access_key, encrypted_key)
  end

  def unlock_local(user_access_key, encryption_key)
    ciphertext = user_access_key.xor(decode(encryption_key))
    unless valid_base64_encoding?(ciphertext)
      raise Pii::EncryptionError, 'invalid base64-encoded ciphertext'
    end
    user_access_key.unlock(encryptor.decrypt(ciphertext, Figaro.env.password_pepper))
  end

  def looks_like_kms?(user_access_key, encryption_key)
    user_access_key.xor(decode(encryption_key)).start_with?(KEY_TYPE[:KMS])
  end

  def aws_client
    @_aws_client ||= Aws::KMS::Client.new(
      instance_profile_credentials_timeout: 1, # defaults to 1 second
      instance_profile_credentials_retries: 5, # defaults to 0 retries
    )
  end

  def encryptor
    @_encryptor ||= Pii::Encryptor.new
  end
end
