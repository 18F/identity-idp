class OtpRequestsTracker < ApplicationRecord
  def self.find_or_create_with_phone(phone)
    tries ||= 1
    phone ||= phone.strip
    phone_fingerprint ||= Pii::Fingerprinter.fingerprint(phone)

    where(phone_fingerprint: phone_fingerprint).
      first_or_create(otp_send_count: 0, otp_last_sent_at: Time.zone.now)
  rescue ActiveRecord::RecordNotUnique
    retry unless (tries -= 1).zero?
    raise
  end
end
