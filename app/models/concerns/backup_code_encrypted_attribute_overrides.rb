module BackupCodeEncryptedAttributeOverrides
  extend ActiveSupport::Concern

  # Override ActiveModel::Dirty methods in order to
  # use code_fingerprint_changed? instead of code_changed?
  # This is necessary because code is no longer an ActiveRecord
  # attribute and all the *_changed and *_was magic no longer works.
  def will_save_change_to_code?
    code_fingerprint_changed?
  end

  def code_in_database
    EncryptedAttribute.new(encrypted_code_was).decrypted if encrypted_code_was.present?
  end

  # Override usual setter method in order to also set fingerprint
  def code=(code)
    set_encrypted_attribute(name: :code, value: code)
    self.code_fingerprint = code.present? ? encrypted_attributes[:code].fingerprint : ''
  end
end
