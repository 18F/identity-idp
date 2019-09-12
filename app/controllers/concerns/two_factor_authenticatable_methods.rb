module TwoFactorAuthenticatableMethods # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern
  include RememberDeviceConcern
  include SecureHeadersConcern

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

  def handle_second_factor_locked_user(type)
    analytics.track_event(Analytics::MULTI_FACTOR_AUTH_MAX_ATTEMPTS)
    handle_max_attempts(type + '_login_attempts')
  end

  def handle_too_many_otp_sends
    analytics.track_event(Analytics::MULTI_FACTOR_AUTH_MAX_SENDS)
    handle_max_attempts('otp_requests')
  end

  def handle_max_attempts(type)
    presenter = TwoFactorAuthCode::MaxAttemptsReachedPresenter.new(
      type,
      decorated_user,
    )
    sign_out
    render_full_width('shared/_failure', locals: { presenter: presenter })
  end

  def require_current_password
    redirect_to user_password_confirm_url
  end

  def current_password_required?
    user_session[:current_password_required] == true
  end

  def check_already_authenticated
    return unless initial_authentication_context?
    return unless user_fully_authenticated?
    return if remember_device_expired_for_sp?

    redirect_to after_otp_verification_confirmation_url
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
    save_remember_device_preference
    user_session.delete(:mfa_device_remembered)
    next_url ||= after_otp_verification_confirmation_url
    reset_otp_session_data
    redirect_to next_url
  end

  def handle_valid_otp_for_context
    if authentication_context?
      handle_valid_otp_for_authentication_context
    elsif confirmation_context?
      handle_valid_otp_for_confirmation_context
    end
  end

  def two_factor_authentication_method
    params[:otp_delivery_preference] || request.path.split('/').last
  end

  # Method will be renamed in the next refactor.
  # You can pass in any "type" with a corresponding I18n key in
  # two_factor_authentication.invalid_#{type}
  def handle_invalid_otp(type: 'otp')
    update_invalid_user

    flash.now[:error] = t("two_factor_authentication.invalid_#{type}")

    if decorated_user.locked_out?
      handle_second_factor_locked_user(type)
    else
      render_show_after_invalid
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
    Funnel::Registration::AddMfa.call(current_user.id, 'phone')
    assign_phone
  end

  def handle_valid_otp_for_authentication_context
    mark_user_session_authenticated(:valid_2fa)
    bypass_sign_in current_user
    create_user_event(:sign_in_after_2fa)

    UpdateUser.new(user: current_user, attributes: { second_factor_attempts_count: 0 }).call
  end

  def assign_phone
    @updating_existing_number = user_session[:phone_id].present?

    if @updating_existing_number && confirmation_context?
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
    return unless MfaPolicy.new(current_user).sufficient_factors_enabled?
    send_phone_added_email
  end

  def send_phone_added_email
    event = create_user_event_with_disavowal(:phone_added, current_user)
    current_user.confirmed_email_addresses.each do |email_address|
      UserMailer.phone_added(email_address, disavowal_token: event.disavowal_token).deliver_later
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
    if after_otp_action_required?
      after_otp_action_url
    else
      after_sign_in_path_for(current_user)
    end
  end

  def after_otp_action_required?
    decorated_user.password_reset_profile.present? ||
      @updating_existing_number ||
      !MfaPolicy.new(current_user).sufficient_factors_enabled?
  end

  def after_otp_action_url
    if @updating_existing_number
      account_url
    elsif decorated_user.password_reset_profile.present?
      reactivate_account_url
    else
      two_2fa_setup
    end
  end

  def mark_user_session_authenticated(authentication_type)
    user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
    user_session[:authn_at] = Time.zone.now
    mark_user_session_authenticated_analytics(authentication_type)
  end

  def mark_user_session_authenticated_analytics(authentication_type)
    analytics.track_event(
      Analytics::USER_MARKED_AUTHED,
      authentication_type: authentication_type,
    )
    GoogleAnalyticsMeasurement.new(
      category: 'authentication',
      event_action: 'authenticated',
      method: authentication_type,
      client_id: ga_cookie_client_id,
    ).send_event
  end

  def direct_otp_code
    current_user.direct_otp if FeatureManagement.prefill_otp_codes?
  end

  def personal_key_unavailable?
    current_user.encrypted_recovery_code_digest.blank?
  end

  def unconfirmed_phone?
    user_session[:unconfirmed_phone] && confirmation_context?
  end

  def phone_view_data
    { confirmation_for_phone_change: confirmation_for_phone_change?,
      phone_number: display_phone_to_deliver_to,
      code_value: direct_otp_code,
      otp_delivery_preference: two_factor_authentication_method,
      otp_make_default_number: selected_otp_make_default_number,
      voice_otp_delivery_unsupported: voice_otp_delivery_unsupported?,
      reenter_phone_number_path: reenter_phone_number_path,
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
    }
  end

  def display_phone_to_deliver_to
    if authentication_context?
      masked_number(phone_configuration.phone)
    else
      user_session[:unconfirmed_phone]
    end
  end

  def voice_otp_delivery_unsupported?
    phone_number = if authentication_context?
                     phone_configuration&.phone
                   else
                     user_session[:unconfirmed_phone]
                   end
    PhoneNumberCapabilities.new(phone_number).sms_only?
  end

  def decorated_user
    current_user.decorate
  end

  def reenter_phone_number_path
    locale = LinkLocaleResolver.locale
    if MfaPolicy.new(current_user).multiple_factors_enabled?
      manage_phone_path(locale: locale)
    else
      phone_setup_path(locale: locale)
    end
  end

  def confirmation_for_phone_change?
    confirmation_context? && MfaContext.new(current_user).phone_configurations.exists?
  end

  def presenter_for_two_factor_authentication_method
    type = DELIVERY_METHOD_MAP[two_factor_authentication_method.to_sym]

    return unless type

    data = send("#{type}_view_data".to_sym)

    TwoFactorAuthCode.const_get("#{type}_delivery_presenter".classify).new(
      data: data,
      view: view_context,
    )
  end

  def phone_configuration
    MfaContext.new(current_user).phone_configuration(user_session[:phone_id])
  end

  def masked_number(number)
    return '' if number.blank?
    "***-***-#{number[-4..-1]}"
  end
end
