class MfasEnabledForUser
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def self.call(user)
    methods_enabled = []
    methods_enabled.push(:piv_cac) if
      TwoFactorAuthentication::PivCacPolicy.new(user).enabled?

    methods_enabled.push(:webauthn) if
      TwoFactorAuthentication::WebauthnPolicy.new(user).enabled?

    methods_enabled.push(:auth_app) if
      TwoFactorAuthentication::AuthAppPolicy.new(user).enabled?

    methods_enabled.push(:phone) if
      TwoFactorAuthentication::PhonePolicy.new(user).enabled?

    methods_enabled.push(:backup_code) if
      TwoFactorAuthentication::BackupCodePolicy.new(user).enabled?

    methods_enabled
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
end
