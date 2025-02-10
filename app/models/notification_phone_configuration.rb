# frozen_string_literal: true

class NotificationPhoneConfiguration < ApplicationRecord
  include EncryptableAttribute

  belongs_to :in_person_enrollment, inverse_of: :notification_phone_configuration
  validates :encrypted_phone, presence: true

  encrypted_attribute(name: :phone)

  def formatted_phone
    PhoneFormatter.format(phone)
  end

  def masked_phone
    PhoneFormatter.mask(phone)
  end

  def friendly_name
    :phone
  end
end
