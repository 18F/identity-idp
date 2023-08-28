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
      digest_pair: password_regional_digest_pair,
      user_uuid: uuid,
    )
    @password = password if result
    result
  end

  def password=(new_password)
    @password = new_password
    return if @password.blank?
    self.encrypted_password_digest, self.encrypted_password_digest_multi_region =
      Encryption::PasswordVerifier.new.create_digest_pair(
        password: @password,
        user_uuid: uuid || generate_uuid,
      )
  end

  def password_regional_digest_pair
    Encryption::RegionalCiphertextPair.new(
      single_region_ciphertext: encrypted_password_digest,
      multi_region_ciphertext: encrypted_password_digest_multi_region,
    )
  end

  def valid_personal_key?(normalized_personal_key)
    Encryption::PasswordVerifier.new.verify(
      password: normalized_personal_key,
      digest_pair: recovery_code_regional_digest_pair,
      user_uuid: uuid,
    )
  end

  def personal_key=(new_personal_key)
    @personal_key = new_personal_key
    return if new_personal_key.blank?
    self.encrypted_recovery_code_digest, self.encrypted_recovery_code_digest_multi_region =
      Encryption::PasswordVerifier.new.create_digest_pair(
        password: new_personal_key,
        user_uuid: uuid || generate_uuid,
      )
    self.encrypted_recovery_code_digest_generated_at = Time.zone.now
  end

  def recovery_code_regional_digest_pair
    Encryption::RegionalCiphertextPair.new(
      single_region_ciphertext: encrypted_recovery_code_digest,
      multi_region_ciphertext: encrypted_recovery_code_digest_multi_region,
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
end
