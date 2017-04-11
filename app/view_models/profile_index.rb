class ProfileIndex
  attr_reader :decorated_user, :decrypted_pii, :personal_key

  def initialize(decrypted_pii:, personal_key:, decorated_user:)
    @decrypted_pii = decrypted_pii
    @personal_key = personal_key
    @decorated_user = decorated_user
  end

  def header_partial
    'profile/header'
  end

  def personal_key_partial
    if personal_key.present?
      'profile/personal_key'
    else
      'shared/null'
    end
  end

  def password_reset_partial
    if decorated_user.password_reset_profile.present?
      'profile/password_reset'
    else
      'shared/null'
    end
  end

  def pending_profile_partial
    if decorated_user.pending_profile.present?
      'profile/pending_profile'
    else
      'shared/null'
    end
  end

  def edit_action_partial
    'profile/actions/edit_action_button'
  end

  def pii_partial
    if decrypted_pii.present?
      'profile/pii'
    else
      'shared/null'
    end
  end

  def totp_partial
    if decorated_user.totp_enabled?
      'profile/actions/disable_totp'
    else
      'profile/actions/enable_totp'
    end
  end

  def manage_personal_key_partial
<<<<<<< HEAD
    if decorated_user.password_reset_profile.present?
      'shared/null'
    else
      'profile/actions/manage_personal_key'
    end
=======
    yield unless current_user.password_reset_profile.present?
  end

  def personal_key_action_partial
    'profile/actions/manage_personal_key'
>>>>>>> Hide p key partial when password_reset present
  end

  def recent_event_partial
    'profile/event_item'
  end

  def header_personalization
    return decrypted_pii.first_name if decrypted_pii.present?

    decorated_user.email
  end

  def totp_content
    return 'profile.index.auth_app_enabled' if decorated_user.totp_enabled?

    'profile.index.auth_app_disabled'
  end

  def recent_events
    decorateed_user.recent_events
  end
<<<<<<< HEAD
=======

  private

  attr_reader :current_user

  def personal_key_item
    render(
      partial: 'profile_item',
      name: render(@view_model.personal_key_item_partial),
      path: manage_personal_key_path,
      action: @view_model.manage_personal_key_partial
    )
  end
>>>>>>> Hide p key partial when password_reset present
end
