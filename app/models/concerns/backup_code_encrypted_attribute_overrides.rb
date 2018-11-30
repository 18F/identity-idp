module BackupCodeEncryptedAttributeOverrides
  extend ActiveSupport::Concern

  class_methods do
    # override this Devise method to support our use of encrypted_code
    def find_first_by_auth_conditions(tainted_conditions, _opts = {})
      email = tainted_conditions[:code]
      return find_with_code(email) if email

      find_by(tainted_conditions)
    end

    # This method smells of :reek:FeatureEnvy
    def find_with_code(code)
      return nil if !code.is_a?(String) || code.empty?

      code_fingerprint = create_fingerprint(code.downcase.strip)
      find_by(code_fingerprint: code_fingerprint)
    end

    # This method smells of :reek:UtilityFunction
    def create_fingerprint(code)
      Pii::Fingerprinter.fingerprint(code)
    end
  end

  # Override ActiveModel::Dirty methods in order to
  # use code_fingerprint_changed? instead of code_changed?
  # This is necessary because email is no longer an ActiveRecord
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
