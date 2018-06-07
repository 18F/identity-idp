# In order to perform scrypt calculation of password in a single
# place for both password and PII encryption, we override
# a few methods to build the encrypted_password via UserAccessKey
#
module UserAccessKeyOverrides
  extend ActiveSupport::Concern

  def valid_password?(password)
    Encryption::PasswordVerifier.verify(
      password: password,
      digest: encrypted_password_digest
    )
  end

  def password=(new_password)
    @password = new_password
    return if @password.blank?
    self.encrypted_password_digest = Encryption::PasswordVerifier.digest(@password)
    # Until we drop the old columns, still write to them so that we can rollback
    write_legacy_password_attributes
  end

  private

  def write_legacy_password_attributes
    password_digest = Encryption::PasswordVerifier::PasswordDigest.parse_from_string(
      encrypted_password_digest
    )
    self.encrypted_password = password_digest.encrypted_password
    self.encryption_key = password_digest.encryption_key
    self.password_salt = password_digest.password_salt
    self.password_cost = password_digest.password_cost
  end
end
