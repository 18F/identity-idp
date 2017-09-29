class UspsConfirmationCode < ApplicationRecord
  belongs_to :profile

  def self.first_with_otp(otp)
    find do |usps_confirmation_code|
      Pii::Fingerprinter.verify(
        Base32::Crockford.normalize(otp),
        usps_confirmation_code.otp_fingerprint
      )
    end
  end

  def expired?
    code_sent_at < Figaro.env.usps_confirmation_max_days.to_i.days.ago
  end
end
