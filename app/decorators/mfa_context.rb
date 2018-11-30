class MfaContext
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def call_configuration(method_symbol)
    return @user.send(method_symbol) if @user.present?
    []
  end

  def phone_configurations
    call_configuration(:phone_configurations)
  end

  def phone_configuration(id = nil)
    return phone_configurations.first if id.blank?
    phone_configurations.find { |cfg| cfg.id.to_s == id.to_s }
  end

  def webauthn_configurations
    call_configuration(:webauthn_configurations)
  end

  def backup_code_configurations
    call_configuration(:backup_code_configurations)
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
    phone_configurations + webauthn_configurations + backup_code_configurations +
      [piv_cac_configuration, auth_app_configuration]
  end

  def enabled_two_factor_configurations_count
    two_factor_configurations.count(&:mfa_enabled?)
  end

  # returns a hash showing the count for each enabled 2FA configuration,
  # such as: { phone: 2, webauthn: 1 }. This is useful for analytics purposes.
  def enabled_two_factor_configuration_counts_hash
    names = enabled_two_factor_configuration_names
    names.each_with_object(Hash.new(0)) { |name, count| count[name] += 1 }
  end

  private

  def enabled_two_factor_configuration_names
    two_factor_configurations.select(&:mfa_enabled?).map(&:friendly_name)
  end
end
