# :reek:TooManyMethods
# :reek:RepeatedConditional
class AccountShow # rubocop:disable Metrics/ClassLength
  attr_reader :decorated_user, :decrypted_pii, :personal_key

  def initialize(decrypted_pii:, personal_key:, decorated_user:)
    @decrypted_pii = decrypted_pii
    @personal_key = personal_key
    @decorated_user = decorated_user
  end

  def header_partial
    'accounts/header'
  end

  def personal_key_partial
    if personal_key.present?
      'accounts/personal_key'
    else
      'shared/null'
    end
  end

  def password_reset_partial
    if decorated_user.password_reset_profile.present?
      'accounts/password_reset'
    else
      'shared/null'
    end
  end

  def pending_profile_partial
    if decorated_user.pending_profile_requires_verification?
      if decorated_user.usps_mail_bounced?
        'accounts/pending_profile_bounced_usps'
      else
        'accounts/pending_profile_usps'
      end
    else
      'shared/null'
    end
  end

  def badges_partial
    'accounts/badges'
  end

  def unphishable_badge_partial
    return 'shared/null' unless MfaPolicy.new(decorated_user.user).unphishable?
    'accounts/unphishable_badge'
  end

  def verified_account_badge_partial
    return 'shared/null' unless decorated_user.identity_verified?
    'accounts/verified_account_badge'
  end

  def edit_action_partial
    'accounts/actions/edit_action_button'
  end

  def manage_action_partial
    'accounts/actions/manage_action_button'
  end

  def delete_action_partial
    'accounts/actions/delete_action_button'
  end

  def pii_partial
    if decrypted_pii.present?
      'accounts/pii'
    elsif decorated_user.identity_verified?
      'accounts/pii_locked'
    else
      'shared/null'
    end
  end

  def totp_partial
    if TwoFactorAuthentication::AuthAppPolicy.new(decorated_user.user).enabled?
      disable_totp_partial
    else
      enable_totp_partial
    end
  end

  def disable_totp_partial
    return 'shared/null' unless MfaPolicy.new(decorated_user.user).more_than_two_factors_enabled?
    'accounts/actions/disable_totp'
  end

  def enable_totp_partial
    'accounts/actions/enable_totp'
  end

  def piv_cac_partial
    if TwoFactorAuthentication::PivCacPolicy.new(decorated_user.user).enabled?
      disable_piv_cac_partial
    else
      enable_piv_cac_partial
    end
  end

  def disable_piv_cac_partial
    return 'shared/null' unless MfaPolicy.new(decorated_user.user).more_than_two_factors_enabled?
    'accounts/actions/disable_piv_cac'
  end

  def enable_piv_cac_partial
    'accounts/actions/enable_piv_cac'
  end

  def manage_personal_key_partial
    yield if decorated_user.password_reset_profile.blank?
  end

  def personal_key_action_partial
    'accounts/actions/manage_personal_key'
  end

  def personal_key_item_partial
    'accounts/personal_key_item_heading'
  end

  def backup_codes_partial
    if TwoFactorAuthentication::BackupCodePolicy.new(decorated_user.user).configured?
      regenerate_backup_codes_partial
    else
      generate_backup_codes_partial
    end
  end

  def regenerate_backup_codes_partial
    'accounts/actions/regenerate_backup_codes'
  end

  def generate_backup_codes_partial
    'accounts/actions/generate_backup_codes'
  end

  def backup_codes_generated_at
    decorated_user.user.backup_code_configurations.order(created_at: :asc).first&.created_at
  end

  def recent_event_partial
    'accounts/event_item'
  end

  def header_personalization
    return decrypted_pii.first_name if decrypted_pii.present?

    EmailContext.new(decorated_user.user).last_sign_in_email_address.email
  end

  def totp_content
    if TwoFactorAuthentication::AuthAppPolicy.new(decorated_user.user).enabled?
      I18n.t('account.index.auth_app_enabled')
    else
      I18n.t('account.index.auth_app_disabled')
    end
  end

  def piv_cac_content
    if TwoFactorAuthentication::PivCacPolicy.new(decorated_user.user).enabled?
      I18n.t('account.index.piv_cac_enabled')
    else
      I18n.t('account.index.piv_cac_disabled')
    end
  end

  delegate :recent_events, :recent_devices, :connected_apps, to: :decorated_user
end
