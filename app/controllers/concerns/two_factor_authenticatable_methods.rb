module TwoFactorAuthenticatableMethods # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern
  include RememberDeviceConcern
  include SecureHeadersConcern
  include MfaSetupConcern

  DELIVERY_METHOD_MAP = {
    authenticator: 'authenticator',
    sms: 'phone',
    voice: 'phone',
    piv_cac: 'piv_cac',
  }.freeze

  private

  def authenticate_user
    authenticate_user!(force: true)
  end

  def handle_second_factor_locked_user(type:, context: nil)
    analytics.multi_factor_auth_max_attempts
    event = PushNotification::MfaLimitAccountLockedEvent.new(user: current_user)
    PushNotification::HttpPush.deliver(event)

    if context && type
      if UserSessionContext.authentication_context?(context)
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
      if UserSessionContext.authentication_context?(context)
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
      decorated_user,
    )
    sign_out
    render_full_width('two_factor_authentication/_locked', locals: { presenter: presenter })
  end

  def require_current_password
    redirect_to user_password_confirm_url
  end

  def current_password_required?
    user_session[:current_password_required] == true
  end

  def check_already_authenticated
    return unless UserSessionContext.initial_authentication_context?(context)
    return unless user_fully_authenticated?
    return if remember_device_expired_for_sp?
    return if service_provider_mfa_policy.user_needs_sp_auth_method_verification?

    redirect_to after_otp_verification_confirmation_url
  end

  def check_sp_required_mfa_bypass
    return unless service_provider_mfa_policy.user_needs_sp_auth_method_verification?
    method = two_factor_authentication_method
    return if service_provider_mfa_policy.aal3_required? &&
              ServiceProviderMfaPolicy::AAL3_METHODS.include?(method)
    return if service_provider_mfa_policy.piv_cac_required? && method == 'piv_cac'
    prompt_to_verify_sp_required_mfa
  end

  def reset_attempt_count_if_user_no_longer_locked_out
    return unless decorated_user.no_longer_locked_out?

    UpdateUser.new(
      user: current_user,
      attributes: {
        second_factor_attempts_count: 0,
        second_factor_locked_at: nil,
      },
    ).call
  end

  def handle_valid_otp(next_url = nil)
    handle_valid_otp_for_context
    handle_remember_device
    next_url ||= after_otp_verification_confirmation_url
    reset_otp_session_data
    redirect_to next_url
  end

  def handle_remember_device
    save_user_opted_remember_device_pref
    save_remember_device_preference
  end

  def handle_valid_otp_for_context
    if UserSessionContext.authentication_context?(context)
      handle_valid_otp_for_authentication_context
    elsif UserSessionContext.confirmation_context?(context)
      handle_valid_otp_for_confirmation_context
    end
  end

  def two_factor_authentication_method
    auth_method = params[:otp_delivery_preference] || request.path.split('/').last
    # the above check gets a wrong value for piv_cac when there is no OTP screen
    # so we patch it to fix LG-3228
    auth_method = 'piv_cac' if auth_method == 'present_piv_cac'
    auth_method
  end

  # Method will be renamed in the next refactor.
  # You can pass in any "type" with a corresponding I18n key in
  # two_factor_authentication.invalid_#{type}
  def handle_invalid_otp(type:, context: nil)
    update_invalid_user

    flash.now[:error] = invalid_otp_error(type)

    if decorated_user.locked_out?
      handle_second_factor_locked_user(context: context, type: type)
    else
      render_show_after_invalid
    end
  end

  def invalid_otp_error(type)
    case type
    when 'otp'
      t('two_factor_authentication.invalid_otp')
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

  def render_show_after_invalid
    @presenter = presenter_for_two_factor_authentication_method
    render :show
  end

  def update_invalid_user
    current_user.second_factor_attempts_count += 1
    attributes = {}
    attributes[:second_factor_locked_at] = Time.zone.now if current_user.max_login_attempts?

    UpdateUser.new(
      user: current_user,
      attributes: attributes,
    ).call
  end

  def handle_valid_otp_for_confirmation_context
    user_session[:authn_at] = Time.zone.now
    assign_phone
    track_mfa_method_added
    @next_mfa_setup_path = next_setup_path
    flash[:success] = t('notices.phone_confirmed')
  end

  def track_mfa_method_added
    mfa_user = MfaContext.new(current_user)
    mfa_count = mfa_user.enabled_mfa_methods_count
    analytics.multi_factor_auth_added_phone(enabled_mfa_methods_count: mfa_count)
    Funnel::Registration::AddMfa.call(current_user.id, 'phone', analytics)
  end

  def handle_valid_otp_for_authentication_context
    user_session[:auth_method] = two_factor_authentication_method.to_s
    mark_user_session_authenticated(:valid_2fa)
    bypass_sign_in current_user
    create_user_event(:sign_in_after_2fa)

    UpdateUser.new(user: current_user, attributes: { second_factor_attempts_count: 0 }).call
  end

  def assign_phone
    @updating_existing_number = user_session[:phone_id].present?

    if @updating_existing_number && UserSessionContext.confirmation_context?(context)
      phone_changed
    else
      phone_confirmed
    end

    update_phone_attributes
  end

  def phone_changed
    create_user_event(:phone_changed)
    send_phone_added_email
  end

  def phone_confirmed
    create_user_event(:phone_confirmed)
    # If the user has MFA configured, then they are not adding a phone during sign up and are
    # instead adding it outside the sign up flow
    return unless MfaPolicy.new(current_user).two_factor_enabled?
    send_phone_added_email
  end

  def send_phone_added_email
    event = create_user_event_with_disavowal(:phone_added, current_user)
    current_user.confirmed_email_addresses.each do |email_address|
      UserMailer.phone_added(current_user, email_address, disavowal_token: event.disavowal_token).
        deliver_now_or_later
    end
  end

  def update_phone_attributes
    UpdateUser.new(
      user: current_user,
      attributes: { phone_id: user_session[:phone_id], phone: user_session[:unconfirmed_phone],
                    phone_confirmed_at: Time.zone.now,
                    otp_make_default_number: selected_otp_make_default_number },
    ).call
  end

  def reset_otp_session_data
    user_session.delete(:unconfirmed_phone)
    user_session[:context] = 'authentication'
  end

  def after_otp_verification_confirmation_url
    return @next_mfa_setup_path if @next_mfa_setup_path
    return account_url if @updating_existing_number
    after_sign_in_path_for(current_user)
  end

  def mark_user_session_authenticated(authentication_type)
    user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION] = false
    user_session[:authn_at] = Time.zone.now
    mark_user_session_authenticated_analytics(authentication_type)
  end

  def mark_user_session_authenticated_analytics(authentication_type)
    analytics.user_marked_authed(
      authentication_type: authentication_type,
    )
  end

  def direct_otp_code
    current_user.direct_otp if FeatureManagement.prefill_otp_codes?
  end

  def personal_key_unavailable?
    current_user.encrypted_recovery_code_digest.blank?
  end

  def user_opted_remember_device_cookie
    cookies.encrypted[:user_opted_remember_device_preference]
  end

  def unconfirmed_phone?
    user_session[:unconfirmed_phone] && UserSessionContext.confirmation_context?(context)
  end

  def phone_view_data
    { confirmation_for_add_phone: confirmation_for_add_phone?,
      phone_number: display_phone_to_deliver_to,
      code_value: direct_otp_code,
      otp_delivery_preference: two_factor_authentication_method,
      otp_make_default_number: selected_otp_make_default_number,
      voice_otp_delivery_unsupported: voice_otp_delivery_unsupported?,
      unconfirmed_phone: unconfirmed_phone?,
      account_reset_token: account_reset_token }.merge(generic_data)
  end

  def selected_otp_make_default_number
    params&.dig(:otp_make_default_number)
  end

  def account_reset_token
    current_user&.account_reset_request&.request_token
  end

  def authenticator_view_data
    {
      two_factor_authentication_method: two_factor_authentication_method,
      user_email: current_user.email_addresses.take.email,
    }.merge(generic_data)
  end

  def generic_data
    {
      personal_key_unavailable: personal_key_unavailable?,
      reauthn: reauthn?,
      user_opted_remember_device_cookie: user_opted_remember_device_cookie,
    }
  end

  def display_phone_to_deliver_to
    if UserSessionContext.authentication_context?(context)
      phone_configuration.masked_phone
    else
      user_session[:unconfirmed_phone]
    end
  end

  def voice_otp_delivery_unsupported?
    if UserSessionContext.authentication_context?(context)
      PhoneNumberCapabilities.new(phone_configuration&.phone, phone_confirmed: true).supports_voice?
    else
      phone = user_session[:unconfirmed_phone]
      PhoneNumberCapabilities.new(phone, phone_confirmed: false).supports_voice?
    end
  end

  def decorated_user
    current_user.decorate
  end

  def confirmation_for_add_phone?
    UserSessionContext.confirmation_context?(context) && user_fully_authenticated?
  end

  def presenter_for_two_factor_authentication_method
    type = DELIVERY_METHOD_MAP[two_factor_authentication_method.to_sym]

    return unless type

    data = send("#{type}_view_data".to_sym)

    TwoFactorAuthCode.const_get("#{type}_delivery_presenter".classify).new(
      data: data,
      view: view_context,
      service_provider: current_sp,
      remember_device_default: remember_device_default,
    )
  end

  def phone_configuration
    MfaContext.new(current_user).phone_configuration(user_session[:phone_id])
  end
end
