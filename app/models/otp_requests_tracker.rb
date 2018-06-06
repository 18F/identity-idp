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

  def self.atomic_increment(id)
    now = Time.zone.now
    # The following sql offers superior db performance with one write and no locking overhead
    query = sanitize_sql_array(['UPDATE otp_requests_trackers ' \
                                 'SET otp_send_count = otp_send_count + 1,' \
                                 'otp_last_sent_at = ?, updated_at = ? ' \
                                 'WHERE id = ?', now, now, id])
    OtpRequestsTracker.connection.execute(query)
    OtpRequestsTracker.find(id)
  end
end
