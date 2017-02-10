module UserEncryptedAttributeOverrides
  extend ActiveSupport::Concern

  # override some Devise methods to support our use of encrypted_email

  class_methods do
    def find_first_by_auth_conditions(tainted_conditions, opts = {})
      if tainted_conditions[:email].present?
        opts[:email_fingerprint] = create_fingerprint(tainted_conditions.delete(:email))
      end
      to_adapter.find_first(devise_parameter_filter.filter(tainted_conditions).merge(opts))
    end

    def find_with_email(email)
      return nil if email.blank?

      email_fingerprint = create_fingerprint(email)
      find_by(email_fingerprint: email_fingerprint)
    end

    def create_fingerprint(email)
      Pii::Fingerprinter.fingerprint(email.downcase)
    end
  end

  # Override ActiveModel::Dirty methods in order to
  # use email_fingerprint_changed? instead of email_changed?
  # This is necessary because email is no longer an ActiveRecord
  # attribute and all the *_changed and *_was magic no longer works.
  def email_changed?
    email_fingerprint_changed?
  end

  def email_was
    EncryptedAttribute.new(encrypted_email_was).decrypted unless encrypted_email_was.blank?
  end

  # Override usual setter method in order to also set fingerprint
  def email=(email)
    set_encrypted_attribute(name: :email, value: email)
    self.email_fingerprint = email.present? ? encrypted_attributes[:email].fingerprint : ''
  end
end
