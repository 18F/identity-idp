class PhoneConfiguration < ApplicationRecord
  include EncryptableAttribute

  belongs_to :user, inverse_of: :phone_configuration
  validates :user_id, presence: true
  validates :encrypted_phone, presence: true

  encrypted_attribute(name: :phone)

  enum delivery_preference: { sms: 0, voice: 1 }
end
