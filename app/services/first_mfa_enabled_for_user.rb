class FirstMfaEnabledForUser
  def self.call(user)
    if TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
      :piv_cac
    elsif TwoFactorAuthentication::WebauthnPolicy.new(user).enabled?
      :webauthn
    elsif TwoFactorAuthentication::AuthAppPolicy.new(user).enabled?
      :auth_app
    elsif TwoFactorAuthentication::PhonePolicy.new(user).enabled?
      :phone
    elsif TwoFactorAuthentication::BackupCodePolicy.new(user).enabled?
      :backup_code
    else
      :error
    end
  end
end
