module UserEncryptedAttributeOverrides
  extend ActiveSupport::Concern

  class_methods do
    # override this Devise method to support our use of encrypted_email
    def find_first_by_auth_conditions(tainted_conditions, _opts = {})
      email = tainted_conditions[:email]
      return find_with_email(email) if email

      find_by(tainted_conditions)
    end

    # :reek:UtilityFunction
    def find_with_email(email)
      email = EmailAddress.where.not(confirmed_at: nil).find_with_email(email) ||
              EmailAddress.where(confirmed_at: nil).find_with_email(email)
      email&.user
    end
  end

  # Override ActiveModel::Dirty methods in order to
  # use email_fingerprint_changed? instead of email_changed?
  # This is necessary because email is no longer an ActiveRecord
  # attribute and all the *_changed and *_was magic no longer works.
  def will_save_change_to_email?
    email_fingerprint_changed?
  end

  def email_in_database
    EncryptedAttribute.new(encrypted_email_was).decrypted if encrypted_email_was.present?
  end

  # Override usual setter method in order to also set fingerprint
  def email=(email)
    set_encrypted_attribute(name: :email, value: email)
    self.email_fingerprint = email.present? ? encrypted_attributes[:email].fingerprint : ''
    return if email_address.blank?
    email_address.email = email
  end
end
