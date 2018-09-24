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
end
