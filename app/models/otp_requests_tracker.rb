class OtpRequestsTracker < ApplicationRecord
  def self.find_or_create_with_phone_and_confirmed(phone, phone_confirmed)
    create_or_find_by(
      phone_fingerprint: Pii::Fingerprinter.fingerprint(phone.strip),
      phone_confirmed: phone_confirmed,
    )
  end

  def self.atomic_increment(id)
    now = Time.zone.now
    # The following sql offers superior db performance with one write and no locking overhead
    query = sanitize_sql_array(
      ['UPDATE otp_requests_trackers ' \
                                       'SET otp_send_count = otp_send_count + 1,' \
                                       'otp_last_sent_at = ?, updated_at = ? ' \
                                       'WHERE id = ?', now, now, id],
    )
    OtpRequestsTracker.connection.execute(query)
    OtpRequestsTracker.find(id)
  end
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: otp_requests_trackers
#
#  id                :integer          not null, primary key
#  attribute_cost    :string
#  otp_last_sent_at  :datetime
#  otp_send_count    :integer          default(0)
#  phone_confirmed   :boolean          default(FALSE)
#  phone_fingerprint :string           default(""), not null
#  created_at        :datetime
#  updated_at        :datetime
#
# Indexes
#
#  index_on_phone_and_confirmed  (phone_fingerprint,phone_confirmed) UNIQUE
#
# rubocop:enable Layout/LineLength
