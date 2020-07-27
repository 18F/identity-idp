class MfaContext
  attr_reader :user, :session

  def initialize(user, session = nil)
    @user = user
    @session = session
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

  def aal3_configurations
    webauthn_configurations + piv_cac_configurations
  end

  def two_factor_configurations
    return piv_cac_configurations if piv_cac_only_required?
    phone_configurations + webauthn_configurations + backup_code_configurations +
      piv_cac_configurations + auth_app_configurations
  end

  # rubocop:disable Metrics/AbcSize
  def enabled_mfa_methods_count
    phone_configurations.to_a.select(&:mfa_enabled?).count +
      webauthn_configurations.to_a.select(&:mfa_enabled?).count +
      (backup_code_configurations.any? ? 1 : 0) +
      piv_cac_configurations.to_a.select(&:mfa_enabled?).count +
      auth_app_configurations.to_a.select(&:mfa_enabled?).count +
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
      auth_app_configurations.to_a.select(&:mfa_enabled?).count
  end

  def unphishable_configuration_count
    webauthn_configurations.to_a.select(&:mfa_enabled?).count +
      piv_cac_configurations.to_a.select(&:mfa_enabled?).count
  end

  private

  def piv_cac_only_required?
    AAL3Policy.new(session: @session, user: user).piv_cac_only_required?
  end

  def personal_key_method_count
    return 0 if Figaro.env.personal_key_retired == 'true'
    (personal_key_configuration.mfa_enabled? ? 1 : 0)
  end

  def enabled_two_factor_configuration_names
    two_factor_configurations.select(&:mfa_enabled?).map(&:friendly_name)
  end
end
