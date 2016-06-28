require 'feature_management'

# rubocop:disable Style/ClassAndModuleChildren
class Devise::TwoFactorAuthenticationController < DeviseController
  # rubocop:enable Style/ClassAndModuleChildren
  prepend_before_action :authenticate_scope!
  before_action :verify_user_is_not_second_factor_locked
  before_action :handle_two_factor_authentication
  before_action :check_already_authenticated

  def new
    current_user.send_new_otp
    flash[:notice] = t('devise.two_factor_authentication.user.new_otp_sent')
    redirect_to user_two_factor_authentication_path(method: 'sms')
  end

  def show
    if use_totp?
      show_totp_prompt
    else
      show_direct_otp_prompt
    end
  end

  def update
    reset_attempt_count_if_user_no_longer_locked_out

    if resource.authenticate_otp(params[:code].strip)
      handle_valid_otp
    else
      handle_invalid_otp
    end
  end

  private

  def check_already_authenticated
    if user_fully_authenticated? && current_user.unconfirmed_mobile.blank?
      redirect_to dashboard_index_url
    end
  end

  def use_totp?
    # Present the TOTP entry screen to users who are TOTP enabled, unless the user explictly
    # selects SMS, or if they are trying to confirm a new mobile.
    current_user.totp_enabled? && params[:method] != 'sms' && current_user.unconfirmed_mobile.blank?
  end

  def authenticate_scope!
    send(:"authenticate_#{resource_name}!", force: true)
    self.resource = send(:"current_#{resource_name}")
  end

  def verify_user_is_not_second_factor_locked
    handle_second_factor_locked_resource if resource.second_factor_locked?
  end

  def reset_attempt_count_if_user_no_longer_locked_out
    return if resource.otp_time_lockout? || resource.second_factor_locked_at.nil?

    resource.update(second_factor_attempts_count: 0, second_factor_locked_at: nil)
  end

  def handle_valid_otp
    user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false

    sign_in resource_name, resource, bypass: true
    flash[:notice] = t('devise.two_factor_authentication.success')

    send_number_change_sms_if_needed

    update_metrics

    update_authenticated_resource

    redirect_valid_resource
  end

  def update_metrics
    ::NewRelic::Agent.increment_metric('Custom/User/OtpAuthenticated')
  end

  def send_number_change_sms_if_needed
    user_decorator = UserDecorator.new(resource)

    if user_decorator.mobile_change_requested?
      SmsSenderNumberChangeJob.perform_later(resource.mobile)
    end
  end

  def update_authenticated_resource
    resource.update(second_factor_attempts_count: 0)
    resource.mobile_confirm
  end

  def redirect_valid_resource
    redirect_to after_sign_in_path_for(resource)
  end

  def show_direct_otp_prompt
    # In development, when SMS is disabled we pre-fill the correct code so that
    # developers can log in without needing to configure SMS delivery.
    if Rails.env.development? && FeatureManagement.sms_disabled?
      @code_value = current_user.direct_otp
    end

    @phone_number = UserDecorator.new(current_user).masked_two_factor_phone_number
    render :show
  end

  def show_totp_prompt
    render :show_totp
  end

  def handle_invalid_otp
    update_invalid_resource if resource.two_factor_enabled?

    flash.now[:error] = t('devise.two_factor_authentication.attempt_failed')

    if resource.second_factor_locked?
      handle_second_factor_locked_resource
    else
      show
    end
  end

  def update_invalid_resource
    resource.second_factor_attempts_count += 1
    # set time lock if max attempts reached
    resource.second_factor_locked_at = Time.zone.now if resource.max_login_attempts?
    resource.save
  end

  def handle_second_factor_locked_resource
    @user_decorator = UserDecorator.new(current_user)
    render :max_login_attempts_reached

    sign_out
  end
end
