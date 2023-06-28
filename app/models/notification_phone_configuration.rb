class NotificationPhoneConfiguration < ApplicationRecord
  include EncryptableAttribute

  belongs_to :in_person_enrollment, inverse_of: :notification_phone_configuration

  encrypted_attribute(name: :phone)

  def formatted_phone
    Phonelib.parse(phone).international
  end

  def masked_phone
    return '' if phone.blank?

    formatted = Phonelib.parse(phone).national
    formatted[0..-5].gsub(/\d/, '*') + formatted[-4..-1]
  end

  def erase_phone_number_and_mark_notification_sent
    self.notification_sent_at = Time.zone.now
    self.phone = nil
  end

  def friendly_name
    :phone
  end
end
