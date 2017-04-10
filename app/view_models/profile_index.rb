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
    'profile/edit_action_button'
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
      'profile/disable_totp'
    else
      'profile/enable_totp'
    end
  end

  def manage_personal_key_partial
    if decorated_user.password_reset_profile.present?
      'shared/null'
    else
      'profile/manage_personal_key'
    end
  end

  def header_personalization
    return decrypted_pii.first_name if decrypted_pii.present?

    decorated_user.email
  end

  private

  attr_reader :current_user
end
