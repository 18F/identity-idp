# In order to perform scrypt calculation of password in a single
# place for both password and PII encryption, we override
# a few methods to build the encrypted_password via UserAccessKey
#
module UserAccessKeyOverrides
  extend ActiveSupport::Concern

  attr_reader :personal_key

  def valid_password?(password)
    result = Encryption::PasswordVerifier.new.verify(
      password: password,
      digest: encrypted_password_digest,
      user_uuid: uuid,
    )
    @password = password if result
    log_password_verification_failure unless result
    result
  end

  def password=(new_password)
    @password = new_password
    return if @password.blank?
    self.encrypted_password_digest = Encryption::PasswordVerifier.new.digest(
      password: @password,
      user_uuid: uuid || generate_uuid,
    )
    generate_password_pii_encryption_key_pair(@password)
  end

  def valid_personal_key?(normalized_personal_key)
    Encryption::PasswordVerifier.new.verify(
      password: normalized_personal_key,
      digest: encrypted_recovery_code_digest,
      user_uuid: uuid,
    )
  end

  def personal_key=(new_personal_key)
    @personal_key = new_personal_key
    return if new_personal_key.blank?
    self.encrypted_recovery_code_digest = Encryption::PasswordVerifier.new.digest(
      password: new_personal_key,
      user_uuid: uuid || generate_uuid,
    )
    self.encrypted_recovery_code_digest_generated_at = Time.zone.now
    generate_recovery_pii_encryption_key_pair(personal_key)
  end

  # This is a callback initiated by Devise after successfully authenticating.
  def after_database_authentication
    rotate_stale_password_digest
  end

  def rotate_stale_password_digest
    return unless Encryption::PasswordVerifier.new.stale_digest?(
      encrypted_password_digest,
    )
    update!(password: password)
  end

  # This is a devise method, which we are overriding. This should not be removed
  # as Devise depends on this for things like building the key to use when
  # storing the user in the session.
  def authenticatable_salt
    return if encrypted_password_digest.blank?
    Encryption::PasswordVerifier::PasswordDigest.parse_from_string(
      encrypted_password_digest,
    ).password_salt
  end

  def generate_password_pii_encryption_key_pair(password)
    key_pair = generate_pii_encryption_key_pair(password)
    self.password_encrypted_pii_encryption_key = key_pair.first
    self.password_pii_encryption_public_key = key_pair.last
  end

  def generate_recovery_pii_encryption_key_pair(personal_key)
    key_pair = generate_pii_encryption_key_pair(personal_key)
    self.recovery_encrypted_pii_encryption_key = key_pair.first
    self.recovery_pii_encryption_public_key = key_pair.last
  end

  def generate_pii_encryption_key_pair(secret)
    user_key = OpenSSL::PKey::EC.generate('secp384r1')
    encrypted_private_key = Encryption::Encryptors::UserPrivateKeyEncryptor.new(secret).encrypt(
      user_key,
      user_uuid: self.uuid,
    )
    public_key = Base64.strict_encode64(user_key.public_to_der)
    [encrypted_private_key, public_key]
  end

  private

  def log_password_verification_failure
    metadata = {
      event: 'Failure to validate password',
      uuid: uuid,
      timestamp: Time.zone.now,
    }
    Rails.logger.info(metadata.to_json)
  end
end
