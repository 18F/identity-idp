# :reek:UtilityFunction
class AnonymousUser
  def uuid
    'anonymous-uuid'
  end

  def second_factor_locked_at
    nil
  end

  def phone_configurations
    PhoneConfiguration.none
  end

  def phone
    nil
  end

  def piv_cac_configurations
    PivCacConfiguration.none
  end

  def auth_app_configurations
    AuthAppConfiguration.none
  end

  def webauthn_configurations
    WebauthnConfiguration.none
  end

  def backup_code_configurations
    BackupCodeConfiguration.none
  end

  def x509_dn_uuid; end

  def email; end

  def email_addresses
    EmailAddress.none
  end

  def confirmed_at
    Time.zone.now
  end
end
