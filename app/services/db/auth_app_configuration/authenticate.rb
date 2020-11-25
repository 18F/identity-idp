module Db
  module AuthAppConfiguration
    class Authenticate
      def self.call(user, code)
        user.auth_app_configurations.each do |cfg|
          totp = ROTP::TOTP.new(cfg.otp_secret_key, digits: TwoFactorAuthenticatable::OTP_LENGTH)
          new_timestamp = totp.verify_with_drift_and_prior(
            code,
            TwoFactorAuthenticatable::ALLOWED_OTP_DRIFT_SECONDS,
            cfg.totp_timestamp,
          )
          return true if update_timestamp(cfg, new_timestamp)
        end
        false
      end

      def self.update_timestamp(cfg, new_timestamp)
        return unless new_timestamp
        cfg.totp_timestamp = new_timestamp
        cfg.save
      end
      private_class_method :update_timestamp
    end
  end
end
