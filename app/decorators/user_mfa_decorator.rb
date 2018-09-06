class UserMfaDecorator
  attr_reader :user

  delegate :phone_configurations, to: :user

  def initialize(user)
    @user = user
  end

  def webauthn_configurations
    user.webauthn_configurations.extending WebauthnConfigurationsExtension
  end

  def piv_cac_configuration
    PivCacConfiguration.new(user)
  end

  def auth_app_configuration
    AuthAppConfiguration.new(user)
  end

  def personal_key_configuration
    PersonalKeyConfiguration.new(user)
  end

  def two_factor_enabled?
    two_factor_configurations.any?(&:mfa_enabled?)
  end

  def two_factor_configurations
    phone_configurations + webauthn_configurations + [piv_cac_configuration, auth_app_configuration]
  end

  def total_mfa_options_enabled
    two_factor_configurations.count(&:mfa_enabled?)
  end
end
