class GpoConfirmationCode < ApplicationRecord
  self.table_name = 'usps_confirmation_codes'

  self.ignored_columns = %(bounced_at)

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
