class FirstMfaEnabledForUser
  # rubocop:disable MethodLength
  def self.call(user)
    if TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
      :piv_cac
    elsif TwoFactorAuthentication::WebauthnPolicy.new(user).enabled?
      :webauthn
    elsif TwoFactorAuthentication::AuthAppPolicy.new(user).enabled?
      :auth_app
    elsif TwoFactorAuthentication::PhonePolicy.new(user).enabled?
      :phone
    elsif TwoFactorAuthentication::BackupCodePolicy.new(user).configured?
      :backup_code
    else
      :error
    end
  end
  # rubocop:enable MethodLength
end
