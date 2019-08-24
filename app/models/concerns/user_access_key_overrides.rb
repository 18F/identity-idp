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
