module Db
  module AuthAppConfiguration
    class Confirm
      def self.call(secret, code)
        totp = ROTP::TOTP.new(secret, digits: TwoFactorAuthenticatable::DIRECT_OTP_LENGTH)
        totp.verify(code, drift_ahead: TwoFactorAuthenticatable::ALLOWED_OTP_DRIFT_SECONDS,
                          drift_behind: TwoFactorAuthenticatable::ALLOWED_OTP_DRIFT_SECONDS)
      end
    end
  end
end
