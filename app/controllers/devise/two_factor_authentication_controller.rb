require 'feature_management'

class Devise::TwoFactorAuthenticationController < DeviseController
  prepend_before_action :authenticate_scope!
  before_action :verify_user_is_not_second_factor_locked
  before_action :handle_two_factor_authentication

  def new
    current_user.send_two_factor_authentication_code
    set_flash_message :success, 'new_otp_sent'
    redirect_to user_two_factor_authentication_path
  end

  def show
    if user_fully_authenticated? && current_user.unconfirmed_mobile.blank?
      redirect_to dashboard_index_url
    end
  end

  def update
    reset_attempt_count_if_user_no_longer_locked_out

    if resource.authenticate_otp(params[:code].strip) || FeatureManagement.pt_mode?
      handle_valid_otp
    else
      handle_invalid_otp
    end
  end

  private

  def authenticate_scope!
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
    warden.session(resource_name)[TwoFactorAuthentication::NEED_AUTHENTICATION] = false

    sign_in resource_name, resource, bypass: true
    set_flash_message :notice, :success

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
    redirect_to(
      after_sign_in_path_for(resource),
      notice: t('upaya.notices.account_created',
                date: (Time.current + 1.year).strftime('%B %d, %Y'))
    )
  end

  def handle_invalid_otp
    update_invalid_resource if resource.two_factor_enabled?

    flash.now[:error] = find_message(:attempt_failed)

    if resource.second_factor_locked?
      handle_second_factor_locked_resource
    else
      render :show
    end
  end

  def update_invalid_resource
    resource.second_factor_attempts_count += 1
    # set time lock if max attempts reached
    resource.second_factor_locked_at = Time.zone.now if resource.max_login_attempts?
    resource.save
  end

  def handle_second_factor_locked_resource
    sign_out(resource)

    render(
      :max_login_attempts_reached,
      locals: { user_decorator: UserDecorator.new(resource) }
    )
  end
end
