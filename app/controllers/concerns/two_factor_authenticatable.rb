module TwoFactorAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user
    before_action :handle_two_factor_authentication
    before_action :require_current_password, if: :current_password_required?
    before_action :check_already_authenticated
    before_action :reset_attempt_count_if_user_no_longer_locked_out, only: :create
    before_action :apply_secure_headers_override, only: [:show, :create]
  end

  DELIVERY_METHOD_MAP = {
    authenticator: 'authenticator',
    sms: 'phone',
    voice: 'phone',
    two_factor_authentication: 'otp',
  }.freeze

  private

  def apply_secure_headers_override
    return unless stored_url_for_user&.start_with?(openid_connect_authorize_path)

    authorize_params = Rack::Utils.parse_nested_query(
      URI(stored_url_for_user).query
    ).with_indifferent_access

    authorize_form = OpenidConnectAuthorizeForm.new(authorize_params)

    return unless authorize_form.valid?

    override_content_security_policy_directives(
      form_action: ["'self'", authorize_form.sp_redirect_uri].compact,
      preserve_schemes: true
    )
  end

  def stored_url_for_user
    session['user_return_to']
  end

  def authenticate_user
    authenticate_user!(force: true)
  end

  def handle_second_factor_locked_user(type)
    analytics.track_event(Analytics::MULTI_FACTOR_AUTH_MAX_ATTEMPTS)

    sign_out

    render 'two_factor_authentication/shared/max_login_attempts_reached', locals: { type: type }
  end

  def require_current_password
    redirect_to user_password_confirm_path
  end

  def current_password_required?
    user_session[:current_password_required] == true
  end

  def check_already_authenticated
    return unless initial_authentication_context?

    redirect_to profile_path if user_fully_authenticated?
  end

  def reset_attempt_count_if_user_no_longer_locked_out
    return unless decorated_user.no_longer_blocked_from_entering_2fa_code?

    UpdateUser.new(
      user: current_user,
      attributes: { second_factor_attempts_count: 0, second_factor_locked_at: nil }
    ).call
  end

  def handle_valid_otp
    if authentication_context?
      handle_valid_otp_for_authentication_context
    elsif idv_or_confirmation_context?
      handle_valid_otp_for_confirmation_context
    end

    redirect_to after_otp_verification_confirmation_path
    reset_otp_session_data
  end

  def two_factor_authentication_method
    params[:two_factor_authentication_method] || request.path.split('/').last
  end

  # Method will be renamed in the next refactor.
  # You can pass in any "type" with a corresponding I18n key in
  # devise.two_factor_authentication.invalid_#{type}
  def handle_invalid_otp(type: 'otp')
    update_invalid_user if current_user.two_factor_enabled? && authentication_context?

    flash.now[:error] = t("devise.two_factor_authentication.invalid_#{type}")

    if decorated_user.blocked_from_entering_2fa_code?
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
    @updating_existing_number = old_phone.present?

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
    current_time = Time.zone.now

    if idv_context?
      Idv::Session.new(user_session, current_user).params['phone_confirmed_at'] = current_time
    else
      UpdateUser.new(
        user: current_user,
        attributes: { phone: user_session[:unconfirmed_phone], phone_confirmed_at: current_time }
      ).call
    end
  end

  def reset_otp_session_data
    user_session.delete(:unconfirmed_phone)
    user_session[:context] = 'authentication'
  end

  def after_otp_verification_confirmation_path
    if idv_context?
      verify_confirmations_path
    elsif after_otp_action_required?
      after_otp_action_path
    else
      after_sign_in_path_for(current_user)
    end
  end

  def after_otp_action_required?
    current_user.password_reset_profile.present? ||
      @updating_existing_number ||
      decorated_user.should_acknowledge_personal_key?(session)
  end

  def after_otp_action_path
    if decorated_user.should_acknowledge_personal_key?(session)
      user_session[:first_time_personal_key_view] = 'true'
      sign_up_personal_key_path
    elsif @updating_existing_number
      profile_path
    elsif current_user.password_reset_profile.present?
      reactivate_profile_path
    else
      profile_path
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
    idv_or_confirmation_context? || !current_user.personal_key.present?
  end

  def unconfirmed_phone?
    user_session[:unconfirmed_phone] && idv_or_confirmation_context?
  end

  def phone_view_data
    {
      phone_number: display_phone_to_deliver_to,
      code_value: direct_otp_code,
      otp_delivery_preference: two_factor_authentication_method,
      reenter_phone_number_path: reenter_phone_number_path,
      unconfirmed_phone: unconfirmed_phone?,
      personal_key_unavailable: personal_key_unavailable?,
      totp_enabled: current_user.totp_enabled?,
    }
  end

  def authenticator_view_data
    {
      two_factor_authentication_method: two_factor_authentication_method,
      user_email: current_user.email,
      personal_key_unavailable: personal_key_unavailable?,
    }
  end

  def otp_view_data
    {
      reenter_phone_number_path: reenter_phone_number_path,
      phone_number: display_phone_to_deliver_to,
      unconfirmed_phone: unconfirmed_phone?,
      personal_key_unavailable: personal_key_unavailable?,
    }
  end

  def display_phone_to_deliver_to
    if authentication_context?
      decorated_user.masked_two_factor_phone_number
    else
      user_session[:unconfirmed_phone]
    end
  end

  def reenter_phone_number_path
    if idv_context?
      verify_phone_path
    elsif current_user.phone.present?
      manage_phone_path
    else
      phone_setup_path
    end
  end

  def presenter_for_two_factor_authentication_method
    type = DELIVERY_METHOD_MAP[two_factor_authentication_method.to_sym]

    return unless type

    data = send("#{type}_view_data".to_sym)

    TwoFactorAuthCode.const_get("#{type}_delivery_presenter".classify).new(data, view_context)
  end
end
