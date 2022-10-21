module Db
  class AuthAppConfiguration
    def self.create(user, otp_secret_key, totp_timestamp, name = Time.zone.now.to_s)
      user.save
      user.auth_app_configurations.create(
        otp_secret_key: otp_secret_key,
        totp_timestamp: totp_timestamp,
        name: name,
      )
    end

    def self.authenticate(user, code)
      user.auth_app_configurations.each do |cfg|
        totp = ROTP::TOTP.new(
          cfg.otp_secret_key,
          digits: TwoFactorAuthenticatable::OTP_LENGTH,
          interval: IdentityConfig.store.totp_code_interval,
        )
        new_timestamp = totp.verify(
          code,
          drift_ahead: TwoFactorAuthenticatable::ALLOWED_OTP_DRIFT_SECONDS,
          drift_behind: TwoFactorAuthenticatable::ALLOWED_OTP_DRIFT_SECONDS,
          after: cfg.totp_timestamp,
        )
        return cfg if update_timestamp(cfg, new_timestamp)
      end
      nil
    end

    def self.confirm(secret, code)
      totp = ROTP::TOTP.new(
        secret,
        digits: TwoFactorAuthenticatable::OTP_LENGTH,
        interval: IdentityConfig.store.totp_code_interval,
      )
      totp.verify(
        code, drift_ahead: TwoFactorAuthenticatable::ALLOWED_OTP_DRIFT_SECONDS,
              drift_behind: TwoFactorAuthenticatable::ALLOWED_OTP_DRIFT_SECONDS
      )
    end

    def self.delete(current_user, auth_app_cfg_id)
      ::AuthAppConfiguration.where(user_id: current_user.id, id: auth_app_cfg_id).delete_all
    end

    def self.update_timestamp(cfg, new_timestamp)
      return unless new_timestamp
      cfg.totp_timestamp = new_timestamp
      cfg.save
    end
    private_class_method :update_timestamp
  end
end
