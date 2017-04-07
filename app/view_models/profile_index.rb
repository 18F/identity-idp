class ProfileIndex
  attr_reader :decrypted_pii, :personal_key

  def initialize(decrypted_pii:, personal_key:, current_user:)
    @decrypted_pii = decrypted_pii
    @personal_key = personal_key
    @current_user = current_user
  end

  def personal_key_partial
    if personal_key.present?
      'profile/personal_key'
    else
      'shared/null'
    end
  end

  def password_reset_partial
    if current_user.password_reset_profile.present?
      'profile/password_reset'
    else
      'shared/null'
    end
  end

  def pii_partial
    if decrypted_pii.present?
      'profile/pii'
    else
      'shared/null'
    end
  end

  def totp_partial
    if current_user.totp_enabled?
      'profile/disable_totp'
    else
      'profile/enable_totp'
    end
  end

  def manage_personal_key_partial
    if current_user.password_reset_profile.present?
      'profile/manage_personal_key'
    else
      'shared/null'
    end
  end

  def recent_event_partial
    'profile/event_datum'
  end

  def recent_events
    current_user.decorate.recent_events
  end

  private

  attr_reader :current_user
end
