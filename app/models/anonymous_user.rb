# frozen_string_literal: true

class AnonymousUser
  def uuid
    'anonymous-uuid'
  end

  def establishing_in_person_enrollment; end

  def pending_in_person_enrollment; end

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

  def locked_out?
    second_factor_locked_at.present? && !lockout_period_expired?
  end

  def identity_verified_with_facial_match?
    false
  end

  def identity_verified?
    false
  end

  def active_profile
    nil
  end

  def unique_session_id
    nil
  end

  def id
    nil
  end
end
