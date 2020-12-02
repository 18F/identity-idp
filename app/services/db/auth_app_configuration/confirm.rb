module Db
  module AuthAppConfiguration
    class Confirm
      def self.call(secret, code)
        totp = ROTP::TOTP.new(secret, digits: TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)
        totp.verify_with_drift_and_prior(code, TwoFactorAuthenticatable::ALLOWED_OTP_DRIFT_SECONDS)
      end
    end
  end
end
