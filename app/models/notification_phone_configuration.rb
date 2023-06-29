class NotificationPhoneConfiguration < ApplicationRecord
  include EncryptableAttribute

  belongs_to :in_person_enrollment, inverse_of: :notification_phone_configuration
  validates :encrypted_phone, presence: true

  encrypted_attribute(name: :phone)

  def formatted_phone
    Phonelib.parse(phone).international
  end

  def masked_phone
    return '' if phone.blank?

    formatted = Phonelib.parse(phone).national
    formatted[0..-5].gsub(/\d/, '*') + formatted[-4..-1]
  end

  def friendly_name
    :phone
  end
end
