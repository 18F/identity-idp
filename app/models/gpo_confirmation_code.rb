class GpoConfirmationCode < ApplicationRecord
  self.ignored_columns = [:bounced_at]

  self.table_name = 'usps_confirmation_codes'

  belongs_to :profile

  def self.first_with_otp(otp)
    find do |gpo_confirmation_code|
      Pii::Fingerprinter.verify(
        Base32::Crockford.normalize(otp),
        gpo_confirmation_code.otp_fingerprint,
      )
    end
  end

  def expired?
    code_sent_at < IdentityConfig.store.usps_confirmation_max_days.days.ago
  end
end

# == Schema Information
#
# Table name: usps_confirmation_codes
#
#  id              :bigint           not null, primary key
#  code_sent_at    :datetime         not null
#  otp_fingerprint :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  profile_id      :integer          not null
#
# Indexes
#
#  index_usps_confirmation_codes_on_otp_fingerprint  (otp_fingerprint)
#  index_usps_confirmation_codes_on_profile_id       (profile_id)
#
