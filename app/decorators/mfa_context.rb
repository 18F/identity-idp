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

  def webauthn_roaming_configurations
    if user.present?
      user.webauthn_configurations.where(platform_authenticator: [false, nil])
    else
      WebauthnConfiguration.none
    end
  end

  def webauthn_platform_configurations
    if user.present?
      user.webauthn_configurations.where(platform_authenticator: true)
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

  def piv_cac_configurations
    if user.present?
      user.piv_cac_configurations
    else
      PivCacConfiguration.none
    end
  end

  def auth_app_configurations
    if user.present?
      user.auth_app_configurations
    else
      AuthAppConfiguration.none
    end
  end

  def personal_key_configuration
    PersonalKeyConfiguration.new(user)
  end

  def phishing_resistant_configurations
    webauthn_configurations + piv_cac_configurations
  end

  def two_factor_configurations
    phone_configurations + webauthn_configurations +
      backup_code_configurations + piv_cac_configurations + auth_app_configurations
  end

  def two_factor_enabled?
    return true if phone_configurations.any?(&:mfa_enabled?)
    return true if piv_cac_configurations.any?(&:mfa_enabled?)
    return true if auth_app_configurations.any?(&:mfa_enabled?)
    return true if backup_code_configurations.any?(&:mfa_enabled?)
    return true if webauthn_configurations.any?(&:mfa_enabled?)
    return false
  end

  def enabled_mfa_methods_count
    phone_configurations.to_a.count(&:mfa_enabled?) +
      webauthn_configurations.to_a.count(&:mfa_enabled?) +
      (backup_code_configurations.any? ? 1 : 0) +
      piv_cac_configurations.to_a.count(&:mfa_enabled?) +
      auth_app_configurations.to_a.count(&:mfa_enabled?) +
      personal_key_method_count
  end

  def enabled_non_restricted_mfa_methods_count
    enabled_mfa_methods_count - phone_configurations.to_a.count(&:mfa_enabled?)
  end

  # returns a hash showing the count for each enabled 2FA configuration,
  # such as: { phone: 2, webauthn: 1 }. This is useful for analytics purposes.
  def enabled_two_factor_configuration_counts_hash
    names = enabled_two_factor_configuration_names
    names.each_with_object(Hash.new(0)) { |name, count| count[name] += 1 }
  end

  def phishable_configuration_count
    phone_configurations.to_a.count(&:mfa_enabled?) +
      (backup_code_configurations.any? ? 1 : 0) +
      auth_app_configurations.to_a.count(&:mfa_enabled?)
  end

  def unphishable_configuration_count
    webauthn_configurations.to_a.count(&:mfa_enabled?) +
      piv_cac_configurations.to_a.count(&:mfa_enabled?)
  end

  private

  def personal_key_method_count
    return 0 if IdentityConfig.store.personal_key_retired
    (personal_key_configuration.mfa_enabled? ? 1 : 0)
  end

  def enabled_two_factor_configuration_names
    two_factor_configurations.select(&:mfa_enabled?).map(&:friendly_name)
  end
end
