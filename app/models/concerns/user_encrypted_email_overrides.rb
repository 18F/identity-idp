module UserEncryptedEmailOverrides
  extend ActiveSupport::Concern

  attr_accessor :email_user_access_key

  # override some Devise methods to support our use of encrypted_email

  class_methods do
    def find_first_by_auth_conditions(tainted_conditions, opts = {})
      if tainted_conditions[:email].present?
        opts[:email_fingerprint] = create_fingerprint(tainted_conditions.delete(:email))
      end
      to_adapter.find_first(devise_parameter_filter.filter(tainted_conditions).merge(opts))
    end

    def find_with_email(email)
      email_fingerprint = create_fingerprint(email)
      find_by(email_fingerprint: email_fingerprint)
    end

    def create_fingerprint(email)
      Pii::Fingerprinter.fingerprint(email.downcase)
    end
  end

  # Override Devise::Models::Confirmable in order to
  # use email_fingerprint_changed instead of email_changed.
  # This is necessary because email is no longer an ActiveRecord
  # attribute and all the *_changed and *_was magic no longer works.
  def postpone_email_change?
    postpone = self.class.reconfirmable &&
               email_fingerprint_changed? &&
               !@bypass_confirmation_postpone &&
               email_fingerprint.present? &&
               (!@skip_reconfirmation_in_callback || email_fingerprint_was.present?)
    @bypass_confirmation_postpone = false
    postpone
  end

  # Override Devise::Models::Confirmable as above,
  # this time using encrypted_email instead to get the plaintext old email.
  def postpone_email_change_until_confirmation_and_regenerate_confirmation_token
    @reconfirmation_required = true
    self.unconfirmed_email = email
    old_email = EncryptedEmail.new(encrypted_email_was).decrypted
    self.email = old_email
    self.confirmation_token = nil
    generate_confirmation_token
  end

  def email
    return '' unless encrypted_email.present?
    @_encrypted_email ||= EncryptedEmail.new(encrypted_email, cost: email_encryption_cost)
    self.email_user_access_key ||= @_encrypted_email.user_access_key
    @_encrypted_email.decrypted
  end

  def email=(email)
    if email.present?
      self.email_user_access_key ||= EncryptedEmail.new_user_access_key(cost: email_encryption_cost)
      @_encrypted_email = EncryptedEmail.new_from_email(email, email_user_access_key)
      self.encrypted_email = @_encrypted_email.encrypted
      self.email_fingerprint = @_encrypted_email.fingerprint
    else
      self.encrypted_email = ''
      self.email_fingerprint = ''
    end
  end
end
