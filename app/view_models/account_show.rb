# :reek:TooManyMethods
class AccountShow
  attr_reader :decorated_user, :decrypted_pii, :personal_key

  def initialize(decrypted_pii:, personal_key:, decorated_user:)
    @decrypted_pii = decrypted_pii
    @personal_key = personal_key
    @decorated_user = decorated_user
  end

  def header_partial
    if decorated_user.identity_verified?
      'accounts/verified_header'
    else
      'accounts/header'
    end
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
    if decorated_user.needs_profile_usps_verification?
      'accounts/pending_profile_usps'
    elsif decorated_user.needs_profile_phone_verification?
      'accounts/pending_profile_phone'
    else
      'shared/null'
    end
  end

  def edit_action_partial
    'accounts/actions/edit_action_button'
  end

  def pii_partial
    if decrypted_pii.present?
      'accounts/pii'
    else
      'shared/null'
    end
  end

  def totp_partial
    if decorated_user.totp_enabled?
      'accounts/actions/disable_totp'
    else
      'accounts/actions/enable_totp'
    end
  end

  def piv_cac_partial
    if decorated_user.piv_cac_enabled?
      'accounts/actions/disable_piv_cac'
    else
      'accounts/actions/enable_piv_cac'
    end
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

  def recent_event_partial
    'accounts/event_item'
  end

  def header_personalization
    return decrypted_pii.first_name if decrypted_pii.present?

    decorated_user.email
  end

  def totp_content
    return 'account.index.auth_app_enabled' if decorated_user.totp_enabled?

    'account.index.auth_app_disabled'
  end

  def piv_cac_content
    return 'account.index.piv_cac_enabled' if decorated_user.piv_cac_enabled?

    'account.index.piv_cac_disabled'
  end

  delegate :recent_events, to: :decorated_user
end
