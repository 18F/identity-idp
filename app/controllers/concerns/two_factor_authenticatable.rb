module TwoFactorAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user
    before_action :handle_two_factor_authentication
    before_action :check_already_authenticated
    before_action :reset_attempt_count_if_user_no_longer_locked_out, only: :create
  end

  DELIVERY_METHOD_MAP = {
    sms: 'phone',
    voice: 'phone'
  }.freeze

  private

  def authenticate_user
    authenticate_user!(force: true)
  end

  def handle_second_factor_locked_user
    analytics.track_event(Analytics::MULTI_FACTOR_AUTH_MAX_ATTEMPTS)

    sign_out

    render 'two_factor_authentication/shared/max_login_attempts_reached'
  end

  def check_already_authenticated
    return unless context == 'authentication'

    redirect_to profile_path if user_fully_authenticated?
  end

  def reset_attempt_count_if_user_no_longer_locked_out
    return unless decorated_user.no_longer_blocked_from_entering_2fa_code?

    current_user.update(second_factor_attempts_count: 0, second_factor_locked_at: nil)
  end

  def handle_valid_otp
    if authentication_context?
      handle_valid_otp_for_authentication_context
    elsif confirmation_context?
      handle_valid_otp_for_confirmation_context
    end

    redirect_to after_otp_verification_confirmation_path
    reset_otp_session_data
  end

  def authentication_context?
    context == 'authentication'
  end

  def confirmation_context?
    context == 'confirmation' || context == 'idv'
  end

  def context
    user_session[:context] || 'authentication'
  end

  def delivery_method
    params[:delivery_method] || request.path.split('/').last
  end

  # Method will be renamed in the next refactor.
  # You can pass in any "type" with a corresponding I18n key in
  # devise.two_factor_authentication.invalid_#{type}
  def handle_invalid_otp(type: 'otp')
    update_invalid_user if current_user.two_factor_enabled? && context == 'authentication'

    flash.now[:error] = t("devise.two_factor_authentication.invalid_#{type}")

    if decorated_user.blocked_from_entering_2fa_code?
      handle_second_factor_locked_user
    else
      render_show_after_invalid
    end
  end

  def render_show_after_invalid
    @presenter = presenter_for(delivery_method, otp_phone_view_data)
    render :show
  end

  def update_invalid_user
    current_user.second_factor_attempts_count += 1
    # set time lock if max attempts reached
    current_user.second_factor_locked_at = Time.zone.now if current_user.max_login_attempts?
    current_user.save
  end

  def handle_valid_otp_for_confirmation_context
    assign_phone

    flash[:success] = t('notices.phone_confirmation_successful')
  end

  def handle_valid_otp_for_authentication_context
    mark_user_session_authenticated
    bypass_sign_in current_user

    current_user.update(second_factor_attempts_count: 0)
  end

  def assign_phone
    @updating_existing_number = old_phone

    if @updating_existing_number && context == 'confirmation'
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
    SmsSenderNumberChangeJob.perform_later(old_phone)
  end

  def phone_confirmed
    create_user_event(:phone_confirmed)
  end

  def update_phone_attributes
    current_time = Time.current

    if context == 'idv'
      Idv::Session.new(user_session, current_user).params['phone_confirmed_at'] = current_time
    else
      current_user.update(phone: user_session[:unconfirmed_phone], phone_confirmed_at: current_time)
    end
  end

  def reset_otp_session_data
    user_session.delete(:unconfirmed_phone)
    user_session[:context] = 'authentication'
  end

  def after_otp_verification_confirmation_path
    if context == 'idv'
      verify_confirmations_path
    elsif @updating_existing_number
      profile_path
    elsif decorated_user.should_acknowledge_recovery_code?(session)
      user_session[:first_time_recovery_code_view] = 'true'
      sign_up_recovery_code_path
    else
      after_sign_in_path_for(current_user)
    end
  end

  def mark_user_session_authenticated
    user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
    user_session[:authn_at] = Time.zone.now
  end

  def otp_phone_view_data
    {
      phone_number: display_phone_to_deliver_to,
      code_value: FeatureManagement.prefill_otp_codes? ? current_user.direct_otp : nil,
      delivery_method: delivery_method,
      reenter_phone_number_path: reenter_phone_number_path,
      unconfirmed_phone: user_session[:unconfirmed_phone],
      unconfirmed_user: !current_user.recovery_code.present?
    }
  end

  def display_phone_to_deliver_to
    if context == 'authentication'
      decorated_user.masked_two_factor_phone_number
    else
      user_session[:unconfirmed_phone]
    end
  end

  def reenter_phone_number_path
    if context == 'idv'
      verify_phone_path
    elsif current_user.phone.present?
      manage_phone_path
    else
      phone_setup_path
    end
  end

  def presenter_for(otp_code_method, data_model)
    type = DELIVERY_METHOD_MAP[otp_code_method.to_sym]
    return unless type
    TwoFactorAuthCode.const_get("#{type}_delivery_presenter".classify).new(data_model)
  end
end
