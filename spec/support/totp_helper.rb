def generate_totp_code(secret)
  ROTP::TOTP.new(secret, interval: IdentityConfig.store.totp_code_interval).at(Time.zone.now)
end
