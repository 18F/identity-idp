module RememberDeviceConcern
  extend ActiveSupport::Concern

  def save_user_opted_remember_device_pref(remember_device_preference)
    cookies.encrypted[:user_opted_remember_device_preference] = remember_device_preference
  end

  def save_remember_device_preference(remember_device_preference)
    return if remember_device_preference != '1' && remember_device_preference != 'true'
    cookies.encrypted[:remember_device] = {
      value: RememberDeviceCookie.new(user_id: current_user.id, created_at: Time.zone.now).to_json,
      expires: remember_device_cookie_expiration,
    }
  end

  def check_remember_device_preference
    return unless UserSessionContext.authentication_context?(context)
    return if remember_device_cookie.nil?
    return unless remember_device_cookie.valid_for_user?(
      user: current_user,
      expiration_interval: decorated_sp_session.mfa_expiration_interval,
    )

    handle_valid_remember_device_cookie(remember_device_cookie: remember_device_cookie)
  end

  def remember_device_cookie
    remember_device_cookie_contents = cookies.encrypted[:remember_device]
    return if remember_device_cookie_contents.blank?
    @remember_device_cookie ||= RememberDeviceCookie.from_json(
      remember_device_cookie_contents,
    )
  end

  def remember_device_expired_for_sp?
    expired_for_interval?(
      current_user,
      decorated_sp_session.mfa_expiration_interval,
    )
  end

  def pii_locked_for_session?(user)
    expired_for_interval?(user, IdentityConfig.store.pii_lock_timeout_in_minutes.minutes)
  end

  def revoke_remember_device(user)
    UpdateUser.new(
      user: user,
      attributes: { remember_device_revoked_at: Time.zone.now },
    ).call
  end

  private

  def expired_for_interval?(user, interval)
    return false unless has_remember_device_auth_event?
    remember_cookie = remember_device_cookie
    return true if remember_cookie.nil?

    !remember_cookie.valid_for_user?(
      user: user,
      expiration_interval: interval,
    )
  end

  def has_remember_device_auth_event?
    auth_methods_session.auth_events.any? do |auth_event|
      auth_event[:auth_method] == TwoFactorAuthenticatable::AuthMethod::REMEMBER_DEVICE
    end
  end

  def handle_valid_remember_device_cookie(remember_device_cookie:)
    mark_user_session_authenticated(
      auth_method: TwoFactorAuthenticatable::AuthMethod::REMEMBER_DEVICE,
      authentication_type: :device_remembered,
    )
    handle_valid_remember_device_analytics(cookie_created_at: remember_device_cookie.created_at)
    redirect_to after_sign_in_path_for(current_user)
  end

  def handle_valid_remember_device_analytics(cookie_created_at:)
    analytics.remembered_device_used_for_authentication(
      cookie_created_at: cookie_created_at,
      cookie_age_seconds: (Time.zone.now - cookie_created_at).to_i,
    )
  end

  def remember_device_cookie_expiration
    if IdentityConfig.store.set_remember_device_session_expiration
      nil
    else
      IdentityConfig.store.remember_device_expiration_hours_aal_1.hours.from_now
    end
  end
end
