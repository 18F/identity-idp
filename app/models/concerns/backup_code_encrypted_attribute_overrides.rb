module BackupCodeEncryptedAttributeOverrides
  extend ActiveSupport::Concern

  # Override ActiveModel::Dirty methods in order to
  # use salted_code_fingerprint_changed? instead of code_changed?
  # This is necessary because code is no longer an ActiveRecord
  # attribute and all the *_changed and *_was magic no longer works.
  def will_save_change_to_code?
    salted_code_fingerprint_changed?
  end

  # Override usual setter method in order to also set fingerprint
  def code=(code)
    code = RandomPhrase.normalize(code)

    if code.present? && code_cost.present? && code_salt.present?
      self.salted_code_fingerprint = BackupCodeConfiguration.scrypt_password_digest(
        password: code,
        salt: code_salt,
        cost: code_cost,
      )
    end
  end
end
