# frozen_string_literal: true

module TwoFactorAuthenticatableMethods
  extend ActiveSupport::Concern
  include RememberDeviceConcern
  include SecureHeadersConcern
  include MfaSetupConcern

  def auth_methods_session
    @auth_methods_session ||= AuthMethodsSession.new(user_session:)
  end

  def handle_valid_verification_for_authentication_context(auth_method:)
    mark_user_session_authenticated(auth_method:, authentication_type: :valid_2fa)
    create_user_event_with_disavowal(:sign_in_after_2fa)

    if IdentityConfig.store.feature_new_device_alert_aggregation_enabled &&
       current_user.sign_in_new_device_at
      UserAlerts::AlertUserAboutNewDevice.send_alert(current_user)
    end

    reset_second_factor_attempts_count
  end

  private

  def authenticate_user
    authenticate_user!(force: true)
  end

  def handle_second_factor_locked_user(type:, context: nil)
    analytics.multi_factor_auth_max_attempts
    event = PushNotification::MfaLimitAccountLockedEvent.new(user: current_user)
    PushNotification::HttpPush.deliver(event)

    if context && type
      if UserSessionContext.authentication_or_reauthentication_context?(context)
        irs_attempts_api_tracker.mfa_login_rate_limited(mfa_device_type: type)
      elsif UserSessionContext.confirmation_context?(context)
        irs_attempts_api_tracker.mfa_enroll_rate_limited(mfa_device_type: type)
      end
    end

    handle_max_attempts(type + '_login_attempts')
  end

  def handle_too_many_otp_sends(phone: nil, context: nil)
    analytics.multi_factor_auth_max_sends

    if context && phone
      if UserSessionContext.authentication_or_reauthentication_context?(context)
        irs_attempts_api_tracker.mfa_login_phone_otp_sent_rate_limited(
          phone_number: phone,
        )
      elsif UserSessionContext.confirmation_context?(context)
        irs_attempts_api_tracker.mfa_enroll_phone_otp_sent_rate_limited(
          phone_number: phone,
        )
      end
    end

    handle_max_attempts('otp_requests')
  end

  def handle_max_attempts(type)
    presenter = TwoFactorAuthCode::MaxAttemptsReachedPresenter.new(
      type,
      current_user,
    )
    sign_out
    render_full_width('two_factor_authentication/_locked', locals: { presenter: presenter })
  end

  def check_already_authenticated
    return unless UserSessionContext.authentication_context?(context)
    return unless user_fully_authenticated?
    return if remember_device_expired_for_sp?
    return if service_provider_mfa_policy.user_needs_sp_auth_method_verification?

    redirect_to after_sign_in_path_for(current_user)
  end

  def check_sp_required_mfa_bypass(auth_method:)
    return unless service_provider_mfa_policy.user_needs_sp_auth_method_verification?
    return if service_provider_mfa_policy.phishing_resistant_required? &&
              TwoFactorAuthenticatable::AuthMethod.phishing_resistant?(auth_method)
    if service_provider_mfa_policy.piv_cac_required? &&
       auth_method == TwoFactorAuthenticatable::AuthMethod::PIV_CAC
      return
    end
    prompt_to_verify_sp_required_mfa
  end

  def reset_attempt_count_if_user_no_longer_locked_out
    return unless current_user.no_longer_locked_out?

    UpdateUser.new(
      user: current_user,
      attributes: {
        second_factor_attempts_count: 0,
        second_factor_locked_at: nil,
      },
    ).call
  end

  def handle_remember_device_preference(remember_device_preference)
    save_user_opted_remember_device_pref(remember_device_preference)
    save_remember_device_preference(remember_device_preference)
  end

  # Method will be renamed in the next refactor.
  # You can pass in any "type" with a corresponding I18n key in
  # two_factor_authentication.invalid_#{type}
  def handle_invalid_otp(type:, context: nil)
    if context == UserSessionContext::AUTHENTICATION_CONTEXT
      handle_invalid_verification_for_authentication_context
    end

    update_invalid_user

    flash.now[:error] = invalid_otp_error(type)

    if current_user.locked_out?
      handle_second_factor_locked_user(context: context, type: type)
    else
      render_show_after_invalid
    end
  end

  def invalid_otp_error(type)
    case type
    when 'otp'
      [t('two_factor_authentication.invalid_otp'),
       otp_attempts_remaining_warning].select(&:present?).join(' ')
    when 'totp'
      t('two_factor_authentication.invalid_otp')
    when 'personal_key'
      t('two_factor_authentication.invalid_personal_key')
    when 'piv_cac'
      t('two_factor_authentication.invalid_piv_cac')
    else
      raise "Unsupported otp method: #{type}"
    end
  end

  def otp_attempts_remaining_warning
    return if otp_attempts_count_remaining >
              IdentityConfig.store.otp_min_attempts_remaining_warning_count
    t(
      'two_factor_authentication.attempt_remaining_warning_html',
      count: otp_attempts_count_remaining,
    )
  end

  def otp_attempts_count_remaining
    IdentityConfig.store.login_otp_confirmation_max_attempts -
      current_user.second_factor_attempts_count
  end

  def render_show_after_invalid
    @presenter = presenter_for_two_factor_authentication_method
    render :show
  end

  def update_invalid_user
    current_user.increment_second_factor_attempts_count!
  end

  def handle_invalid_verification_for_authentication_context
    create_user_event(:sign_in_unsuccessful_2fa)
  end

  def handle_valid_verification_for_confirmation_context(auth_method:)
    mark_user_session_authenticated(auth_method:, authentication_type: :valid_2fa_confirmation)
    reset_second_factor_attempts_count
  end

  def reset_second_factor_attempts_count
    UpdateUser.new(user: current_user, attributes: { second_factor_attempts_count: 0 }).call
  end

  def mark_user_session_authenticated(auth_method:, authentication_type:)
    auth_methods_session.authenticate!(auth_method)
    mark_user_session_authenticated_analytics(authentication_type)
  end

  def mark_user_session_authenticated_analytics(authentication_type)
    analytics.user_marked_authed(
      authentication_type: authentication_type,
    )
  end

  def otp_expiration
    return if current_user.direct_otp_sent_at.blank?
    current_user.direct_otp_sent_at + TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_SECONDS
  end

  def user_opted_remember_device_cookie
    cookies.encrypted[:user_opted_remember_device_preference]
  end

  def generic_data
    {
      user_opted_remember_device_cookie: user_opted_remember_device_cookie,
      reauthn: UserSessionContext.reauthentication_context?(user_session[:context]),
    }
  end
end
