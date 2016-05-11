module Devise
  module TwoFactorAuthenticationHelper
    def otp_drift_time_in_minutes
      Devise.allowed_otp_drift_seconds / 60
    end
  end
end
