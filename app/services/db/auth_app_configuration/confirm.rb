module Db
  module AuthAppConfiguration
    class Confirm
      def self.call(secret, code)
        totp = ROTP::TOTP.new(secret, digits: TwoFactorAuthenticatable.direct_otp_length)
        totp.verify_with_drift_and_prior(code, TwoFactorAuthenticatable.allowed_otp_drift_seconds)
      end
    end
  end
end
