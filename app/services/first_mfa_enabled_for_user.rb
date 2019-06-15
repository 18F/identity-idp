class FirstMfaEnabledForUser
  def self.call(user)
    return :piv_cac if TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
    return :webauthn if TwoFactorAuthentication::WebauthnPolicy.new(user).enabled?
    return :auth_app if TwoFactorAuthentication::AuthAppPolicy.new(user).enabled?
    return :phone if TwoFactorAuthentication::PhonePolicy.new(user).enabled?
    return :backup_code if TwoFactorAuthentication::BackupCodePolicy.new(user).enabled?
    :error
  end
end
