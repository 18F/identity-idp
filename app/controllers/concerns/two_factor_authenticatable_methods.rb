# frozen_string_literal: true

module TwoFactorAuthenticatableMethods
  extend ActiveSupport::Concern
  include RememberDeviceConcern
  include SecureHeadersConcern
  include MfaSetupConcern
  include NewDeviceConcern

  def auth_methods_session
    @auth_methods_session ||= AuthMethodsSession.new(user_session:)
  end

  def handle_verification_for_authentication_context(result:, auth_method:, extra_analytics: nil)
    increment_mfa_selection_attempt_count(auth_method)
    recaptcha_annotation = annotate_recaptcha(
      result.success? ? RecaptchaAnnotator::AnnotationReasons::PASSED_TWO_FACTOR
                      : RecaptchaAnnotator::AnnotationReasons::FAILED_TWO_FACTOR,
    )
    analytics.multi_factor_auth(
      **result,
      multi_factor_auth_method: auth_method,
      enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
      new_device: new_device?,
      **extra_analytics.to_h,
      attempts: mfa_attempts_count,
      recaptcha_annotation:,
    )

    attempts_api_tracker.mfa_login_auth_submitted(
      mfa_device_type: mfa_device_type(auth_method:),
      success: result.success?,
      failure_reason: format_failures(auth_method:, result:),
      reauthentication: generic_data[:reauthn],
    )

    if result.success?
      handle_valid_verification_for_authentication_context(auth_method:)
      user_session.delete(:mfa_attempts)
      session.delete(:sign_in_recaptcha_assessment_id) if sign_in_recaptcha_annotation_enabled?
    else
      handle_invalid_verification_for_authentication_context
    end
  end

  def annotate_recaptcha(reason)
    if sign_in_recaptcha_annotation_enabled?
      RecaptchaAnnotator.annotate(assessment_id: session[:sign_in_recaptcha_assessment_id], reason:)
    end
  end

  private

  def sign_in_recaptcha_annotation_enabled?
    IdentityConfig.store.sign_in_recaptcha_annotation_enabled
  end

  def handle_valid_verification_for_authentication_context(auth_method:)
    mark_user_session_authenticated(auth_method:, authentication_type: :valid_2fa)
    disavowal_event, disavowal_token = create_user_event_with_disavowal(:sign_in_after_2fa)

    if new_device?
      if current_user.sign_in_new_device_at.blank?
        if sign_in_notification_timeframe_expired_event.present?
          current_user.update(
            sign_in_new_device_at: sign_in_notification_timeframe_expired_event.created_at,
          )
        else
          current_user.update(sign_in_new_device_at: disavowal_event.created_at)
          analytics.sign_in_notification_timeframe_expired_absent
        end
      end

      UserAlerts::AlertUserAboutNewDevice.send_alert(
        user: current_user,
        disavowal_event:,
        disavowal_token:,
      )
    end

    set_new_device_session(false)
    reset_second_factor_attempts_count
  end

  def authenticate_user
    authenticate_user!(force: true)
  end

  def handle_second_factor_locked_user(type:, context: nil)
    analytics.multi_factor_auth_max_attempts

    if context
      if UserSessionContext.confirmation_context?(context)
        attempts_api_tracker.mfa_enroll_code_rate_limited(mfa_device_type: type)
      elsif UserSessionContext.authentication_context?(context)
        attempts_api_tracker.mfa_submission_code_rate_limited(mfa_device_type: type)
      end
    end

    event = PushNotification::MfaLimitAccountLockedEvent.new(user: current_user)
    PushNotification::HttpPush.deliver(event)
    handle_max_attempts(type + '_login_attempts')
  end

  def handle_too_many_otp_sends
    analytics.multi_factor_auth_max_sends
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

  def reset_attempt_count_if_user_no_longer_locked_out
    return unless current_user.no_longer_locked_out?

    current_user.update!(
      second_factor_attempts_count: 0,
      second_factor_locked_at: nil,
    )
  end

  def sign_in_notification_timeframe_expired_event
    return @sign_in_notification_timeframe_expired_event if defined?(
      @sign_in_notification_timeframe_expired_event
    )
    @sign_in_notification_timeframe_expired_event = current_user.events
      .where(
        event_type: 'sign_in_notification_timeframe_expired',
        created_at: (IdentityConfig.store.session_total_duration_timeout_in_minutes.minutes.ago..),
      )
      .order(created_at: :desc)
      .limit(1)
      .take
  end

  def handle_remember_device_preference(remember_device_preference)
    save_user_opted_remember_device_pref(remember_device_preference)
    save_remember_device_preference(remember_device_preference)
  end

  def increment_mfa_selection_attempt_count(auth_method)
    user_session[:mfa_attempts] ||= {}
    user_session[:mfa_attempts][:attempts] ||= 0
    if user_session[:mfa_attempts][:auth_method] != auth_method
      user_session[:mfa_attempts][:attempts] = 0
    end
    user_session[:mfa_attempts][:attempts] += 1
    user_session[:mfa_attempts][:auth_method] = auth_method
  end

  def mfa_attempts_count
    user_session.dig(:mfa_attempts, :attempts)
  end

  # You can pass in any "type" with a corresponding I18n key in
  # two_factor_authentication.invalid_#{type}
  def handle_invalid_mfa(type:, context:)
    update_invalid_user

    flash.now[:error] = invalid_error(type)

    if current_user.locked_out?
      handle_second_factor_locked_user(type:, context:)
    else
      render_show_after_invalid
    end
  end

  def invalid_error(type)
    case type
    when 'otp'
      [t('two_factor_authentication.invalid_otp'),
       otp_attempts_remaining_warning].select(&:present?).join(' ')
    when 'totp'
      t('two_factor_authentication.invalid_otp')
    when 'personal_key'
      t('two_factor_authentication.invalid_personal_key')
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
    current_user.update!(second_factor_attempts_count: 0)
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

  def mfa_device_type(auth_method:)
    return 'otp' if auth_method == TwoFactorAuthenticatable::AuthMethod::SMS

    auth_method
  end

  def format_failures(auth_method:, result:)
    if auth_method == TwoFactorAuthenticatable::AuthMethod::PIV_CAC
      return nil unless result.to_h[:errors].present?

      type, error = result.to_h[:errors][:type].split('.')
      return { type.to_sym => [error.to_sym] }
    end

    attempts_api_tracker.parse_failure_reason(result)
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
