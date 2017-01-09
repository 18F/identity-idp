module UserEncryptedAttributeOverrides
  extend ActiveSupport::Concern

  attr_accessor :attribute_user_access_key

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
    old_email = EncryptedAttribute.new(encrypted_email_was).decrypted
    self.email = old_email
    self.confirmation_token = nil
    generate_confirmation_token
  end

  def email
    get_encrypted_attribute(name: :email, default: '')
  end

  def email=(email)
    set_encrypted_attribute(name: :email, value: email, default: '')
    self.email_fingerprint = email.present? ? encrypted_attributes[:email].fingerprint : ''
  end

  def stale_encrypted_email?
    return false unless email.present?
    encrypted_attributes[:email].stale?
  end

  def phone
    get_encrypted_attribute(name: :phone, default: nil)
  end

  def phone=(phone)
    set_encrypted_attribute(name: :phone, value: phone, default: nil)
  end

  def stale_encrypted_phone?
    return false unless phone.present?
    encrypted_attributes[:phone].stale?
  end

  private

  def encrypted_attributes
    @_encrypted_attributes ||= {}
  end

  def get_encrypted_attribute(name:, default:)
    getter = encrypted_attribute_name(name)
    encrypted_string = self[getter]
    return default unless encrypted_string.present?
    encrypted_attribute = encrypted_attributes[name]
    return encrypted_attribute.decrypted if encrypted_attribute.present?
    build_encrypted_attribute(name, encrypted_string).decrypted
  end

  def build_encrypted_attribute(name, encrypted_string)
    encrypted_attribute = EncryptedAttribute.new(
      encrypted_string,
      cost: attribute_cost,
      user_access_key: attribute_user_access_key
    )
    self.attribute_user_access_key ||= encrypted_attribute.user_access_key
    encrypted_attributes[name] = encrypted_attribute
  end

  def set_encrypted_attribute(name:, value:, default:)
    setter = encrypted_attribute_name(name)
    new_value = default
    if value.present?
      new_value = build_encrypted_attribute_from_plain(name, value).encrypted
    end
    self[setter] = new_value
  end

  def build_encrypted_attribute_from_plain(name, plain_value)
    self.attribute_user_access_key ||= new_attribute_user_access_key
    encrypted_attributes[name] = EncryptedAttribute.new_from_decrypted(
      plain_value.downcase.strip,
      attribute_user_access_key
    )
  end

  def encrypted_attribute_name(name)
    "encrypted_#{name}".to_sym
  end

  def new_attribute_user_access_key
    EncryptedAttribute.new_user_access_key(cost: attribute_cost)
  end
end
