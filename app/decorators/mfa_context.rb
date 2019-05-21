# :reek:RepeatedConditional

class MfaContext
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def phone_configurations
    if user.present?
      user.phone_configurations
    else
      PhoneConfiguration.none
    end
  end

  def phone_configuration(id = nil)
    return user.default_phone_configuration if id.blank?
    phone_configurations.find { |cfg| cfg.id.to_s == id.to_s }
  end

  def webauthn_configurations
    if user.present?
      user.webauthn_configurations
    else
      WebauthnConfiguration.none
    end
  end

  def backup_code_configurations
    if user.present?
      user.backup_code_configurations.unused
    else
      BackupCodeConfiguration.none
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
    phone_configurations + webauthn_configurations + backup_code_configurations +
      [piv_cac_configuration, auth_app_configuration]
  end

  # rubocop:disable Metrics/AbcSize
  def enabled_mfa_methods_count
    phone_configurations.to_a.select(&:mfa_enabled?).count +
      webauthn_configurations.to_a.select(&:mfa_enabled?).count +
      (backup_code_configurations.any? ? 1 : 0) +
      (piv_cac_configuration.mfa_enabled? ? 1 : 0) +
      (auth_app_configuration.mfa_enabled? ? 1 : 0) +
      personal_key_method_count
  end
  # rubocop:enable Metrics/AbcSize

  # returns a hash showing the count for each enabled 2FA configuration,
  # such as: { phone: 2, webauthn: 1 }. This is useful for analytics purposes.
  def enabled_two_factor_configuration_counts_hash
    names = enabled_two_factor_configuration_names
    names.each_with_object(Hash.new(0)) { |name, count| count[name] += 1 }
  end

  def phishable_configuration_count
    phone_configurations.to_a.select(&:mfa_enabled?).count +
      (backup_code_configurations.any? ? 1 : 0) +
      (auth_app_configuration.mfa_enabled? ? 1 : 0)
  end

  def unphishable_configuration_count
    webauthn_configurations.to_a.select(&:mfa_enabled?).count +
      (piv_cac_configuration.mfa_enabled? ? 1 : 0)
  end

  private

  def personal_key_method_count
    return 0 if Figaro.env.personal_key_retired == 'true'
    (personal_key_configuration.mfa_enabled? ? 1 : 0)
  end

  def enabled_two_factor_configuration_names
    two_factor_configurations.select(&:mfa_enabled?).map(&:friendly_name)
  end
end
