class EmailAddress < ApplicationRecord
  include EncryptableAttribute

  encrypted_attribute_without_setter(name: :email)

  belongs_to :user, inverse_of: :email_address
  validates :user_id, presence: true
  validates :encrypted_email, presence: true
  validates :email_fingerprint, presence: true

  def email=(email)
    set_encrypted_attribute(name: :email, value: email)
    self.email_fingerprint = email.present? ? encrypted_attributes[:email].fingerprint : ''
  end

  def confirmed?
    confirmed_at.present?
  end

  def stale_email_fingerprint?
    Pii::Fingerprinter.stale?(email, email_fingerprint)
  end

  class << self
    def find_with_email(email)
      return nil if !email.is_a?(String) || email.empty?

      email = email.downcase.strip
      email_fingerprint = create_fingerprint(email)
      find_by(email_fingerprint: email_fingerprint)
    end

    private

    def create_fingerprint(email)
      Pii::Fingerprinter.fingerprint(email)
    end
  end
end
