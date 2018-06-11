# In order to perform scrypt calculation of password in a single
# place for both password and PII encryption, we override
# a few methods to build the encrypted_password via UserAccessKey
#
module UserAccessKeyOverrides
  extend ActiveSupport::Concern

  def valid_password?(password)
    result = Encryption::PasswordVerifier.verify(
      password: password,
      digest: encrypted_password_digest
    )
    log_password_verification_failure unless result
    result
  end

  def password=(new_password)
    @password = new_password
    return if @password.blank?
    digest = Encryption::PasswordVerifier.digest(@password)
    self.encrypted_password_digest = digest.to_s
    # Until we drop the old columns, still write to them so that we can rollback
    write_legacy_password_attributes(digest)
  end

  private

  def write_legacy_password_attributes(digest)
    self.encrypted_password = digest.encrypted_password
    self.encryption_key = digest.encryption_key
    self.password_salt = digest.password_salt
    self.password_cost = digest.password_cost
  end

  def log_password_verification_failure
    metadata = {
      event: 'Failure to validate password',
      uuid: uuid,
      timestamp: Time.zone.now,
    }
    Rails.logger.info(metadata.to_json)
  end
end
