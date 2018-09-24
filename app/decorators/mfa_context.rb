class MfaContext
  attr_reader :user

  EMPTY_WEBAUTHN_ARRAY = begin
    array = []
    def array.selection_presenters
      []
    end
    array.freeze
  end

  def initialize(user)
    @user = user
  end

  def phone_configurations
    if user.present?
      user.phone_configurations
    else
      []
    end
  end

  def webauthn_configurations
    if user.present?
      user.webauthn_configurations.extending WebauthnConfigurationsExtension
    else
      EMPTY_WEBAUTHN_ARRAY
    end
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

  def two_factor_configurations
    phone_configurations + webauthn_configurations + [piv_cac_configuration, auth_app_configuration]
  end

  def enabled_two_factor_configurations_count
    two_factor_configurations.count(&:mfa_enabled?)
  end
end
