module TwoFactorAuthenticatable
  extend ActiveSupport::Concern
  include RememberDeviceConcern
  include SecureHeadersConcern

  included do
    before_action :authenticate_user
    before_action :require_current_password, if: :current_password_required?
    before_action :check_already_authenticated
    before_action :reset_attempt_count_if_user_no_longer_locked_out, only: :create
    before_action :apply_secure_headers_override, only: %i[show create]
  end

  DELIVERY_METHOD_MAP = {
    authenticator: 'authenticator',
    sms: 'phone',
    voice: 'phone',
  }.freeze

  private

  def authenticate_user
    authenticate_user!(force: true)
  end

  def handle_second_factor_locked_user(type)
    analytics.track_event(Analytics::MULTI_FACTOR_AUTH_MAX_ATTEMPTS)
    decorator = current_user.decorate
    sign_out
    render(
      'two_factor_authentication/shared/max_login_attempts_reached',
      locals: { type: type, decorator: decorator }
    )
  end

  def handle_too_many_otp_sends
    analytics.track_event(Analytics::MULTI_FACTOR_AUTH_MAX_SENDS)
    decorator = current_user.decorate
    sign_out
    render(
      'two_factor_authentication/shared/max_otp_requests_reached',
      locals: { decorator: decorator }
    )
  end

  def require_current_password
    redirect_to user_password_confirm_url
  end

  def current_password_required?
    user_session[:current_password_required] == true
  end

  def check_already_authenticated
    return unless initial_authentication_context?

    redirect_to account_url if user_fully_authenticated?
  end

  def reset_attempt_count_if_user_no_longer_locked_out
    return unless decorated_user.no_longer_locked_out?

    UpdateUser.new(
      user: current_user,
      attributes: {
        second_factor_attempts_count: 0,
        second_factor_locked_at: nil,
      }
    ).call
  end

  def handle_valid_otp
    if authentication_context?
      handle_valid_otp_for_authentication_context
    elsif idv_or_confirmation_context? || profile_context?
      handle_valid_otp_for_confirmation_context
    end
    save_remember_device_preference

    redirect_to after_otp_verification_confirmation_url
    reset_otp_session_data
  end

  def two_factor_authentication_method
    params[:otp_delivery_preference] || request.path.split('/').last
  end

  # Method will be renamed in the next refactor.
  # You can pass in any "type" with a corresponding I18n key in
  # devise.two_factor_authentication.invalid_#{type}
  def handle_invalid_otp(type: 'otp')
    update_invalid_user

    flash.now[:error] = t("devise.two_factor_authentication.invalid_#{type}")

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
      attributes: attributes
    ).call
  end

  def handle_valid_otp_for_confirmation_context
    assign_phone
  end

  def handle_valid_otp_for_authentication_context
    mark_user_session_authenticated
    bypass_sign_in current_user

    UpdateUser.new(user: current_user, attributes: { second_factor_attempts_count: 0 }).call
  end

  def assign_phone
    @updating_existing_number = old_phone.present? && !profile_context?

    if @updating_existing_number && confirmation_context?
      phone_changed
    else
      phone_confirmed
    end

    update_phone_attributes
  end

  def old_phone
    current_user.phone
  end

  def phone_changed
    create_user_event(:phone_changed)
    UserMailer.phone_changed(current_user).deliver_later
  end

  def phone_confirmed
    create_user_event(:phone_confirmed)
  end

  def update_phone_attributes
    if idv_or_profile_context?
      update_idv_state
    else
      UpdateUser.new(
        user: current_user,
        attributes: { phone: user_session[:unconfirmed_phone], phone_confirmed_at: Time.zone.now }
      ).call
    end
  end

  def update_idv_state
    if idv_context?
      confirm_idv_session_phone
    elsif profile_context?
      Idv::ProfileActivator.new(user: current_user).call
    end
  end

  def confirm_idv_session_phone
    idv_session = Idv::Session.new(
      user_session: user_session,
      current_user: current_user,
      issuer: sp_session[:issuer]
    )
    idv_session.user_phone_confirmation = true
    idv_session.params['phone_confirmed_at'] = Time.zone.now
  end

  def reset_otp_session_data
    user_session.delete(:unconfirmed_phone)
    user_session[:context] = 'authentication'
  end

  def after_otp_verification_confirmation_url
    if idv_context?
      verify_review_url
    elsif after_otp_action_required?
      after_otp_action_url
    else
      after_sign_in_path_for(current_user)
    end
  end

  def after_otp_action_required?
    decorated_user.password_reset_profile.present? ||
      @updating_existing_number ||
      decorated_user.should_acknowledge_personal_key?(session)
  end

  def after_otp_action_url
    if decorated_user.should_acknowledge_personal_key?(user_session)
      sign_up_personal_key_url
    elsif @updating_existing_number
      account_url
    elsif decorated_user.password_reset_profile.present?
      reactivate_account_url
    else
      account_url
    end
  end

  def mark_user_session_authenticated
    user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
    user_session[:authn_at] = Time.zone.now
  end

  def direct_otp_code
    current_user.direct_otp if FeatureManagement.prefill_otp_codes?
  end

  def personal_key_unavailable?
    idv_or_confirmation_context? || profile_context? || current_user.personal_key.blank?
  end

  def unconfirmed_phone?
    user_session[:unconfirmed_phone] && idv_or_confirmation_context?
  end

  # rubocop:disable MethodLength
  def phone_view_data
    {
      confirmation_for_phone_change: confirmation_for_phone_change?,
      confirmation_for_idv: idv_context?,
      phone_number: display_phone_to_deliver_to,
      code_value: direct_otp_code,
      otp_delivery_preference: two_factor_authentication_method,
      voice_otp_delivery_unsupported: voice_otp_delivery_unsupported?,
      reenter_phone_number_path: reenter_phone_number_path,
      unconfirmed_phone: unconfirmed_phone?,
      totp_enabled: current_user.totp_enabled?,
      remember_device_available: !idv_context?,
    }.merge(generic_data)
  end
  # rubocop:enable MethodLength

  def authenticator_view_data
    {
      two_factor_authentication_method: two_factor_authentication_method,
      user_email: current_user.email,
      remember_device_available: false,
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
      decorated_user.masked_two_factor_phone_number
    else
      user_session[:unconfirmed_phone]
    end
  end

  def voice_otp_delivery_unsupported?
    phone_number = if authentication_context?
                     current_user.phone
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
    if idv_context?
      verify_phone_path(locale: locale)
    elsif current_user.phone.present?
      manage_phone_path(locale: locale)
    else
      phone_setup_path(locale: locale)
    end
  end

  def confirmation_for_phone_change?
    confirmation_context? && current_user.phone.present?
  end

  def presenter_for_two_factor_authentication_method
    type = DELIVERY_METHOD_MAP[two_factor_authentication_method.to_sym]

    return unless type

    data = send("#{type}_view_data".to_sym)

    TwoFactorAuthCode.const_get("#{type}_delivery_presenter".classify).new(
      data: data,
      view: view_context
    )
  end
end
