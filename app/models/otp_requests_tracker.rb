class OtpRequestsTracker < ActiveRecord::Base
  include EncryptableAttribute

  encrypted_attribute_without_setter(name: :phone)

  def self.find_or_create_with_phone(phone)
    tries ||= 1
    phone ||= phone.strip
    phone_fingerprint ||= Pii::Fingerprinter.fingerprint(phone)

    where(phone_fingerprint: phone_fingerprint).
      first_or_create(phone: phone, otp_send_count: 0, otp_last_sent_at: Time.zone.now)
  rescue ActiveRecord::RecordNotUnique
    retry unless (tries -= 1).zero?
    raise
  end

  def phone=(phone)
    set_encrypted_attribute(name: :phone, value: phone)
    self.phone_fingerprint = phone.present? ? encrypted_attributes[:phone].fingerprint : ''
  end
end
