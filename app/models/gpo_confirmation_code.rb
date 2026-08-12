# frozen_string_literal: true

class GpoConfirmationCode < ApplicationRecord
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

  def max_days
    GpoConfirmationMaxDaysCalculator.max_days_for_state(state)
  end

  def expired?(as_of: Time.zone.now)
    code_sent_at < as_of - max_days.days
  end
end
