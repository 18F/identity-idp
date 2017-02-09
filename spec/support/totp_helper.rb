def generate_totp_code(secret)
  ROTP::TOTP.new(secret).at(Time.zone.now, true)
end
