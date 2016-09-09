module PhoneConfirmationFlow
  extend ActiveSupport::Concern

  included do
    before_action :set_fallback_vars, only: :show
  end

  def show
    raise 'must override'
  end

  def this_phone_confirmation_path
    raise 'must override'
  end

  def assign_phone
    raise 'must override'
  end

  def after_confirmation_path
    raise 'must override'
  end

  def this_send_confirmation_code_path
    raise 'must override'
  end

  def send_code
    send_confirmation_code
    redirect_to this_phone_confirmation_path
  end

  def confirm
    if params['code'] == confirmation_code
      process_valid_code
    else
      process_invalid_code
    end
  end

  private

  def generate_confirmation_code
    digits = Devise.direct_otp_length
    random_base10(digits)
  end

  def random_base10(digits)
    SecureRandom.random_number(10**digits).to_s.rjust(digits, '0')
  end

  def process_invalid_code
    analytics.track_event('User entered invalid phone confirmation code')
    flash[:error] = t('errors.invalid_confirmation_code')
    redirect_to this_phone_confirmation_path
  end

  def process_valid_code
    assign_phone
    clear_session_data

    flash[:success] = t('notices.phone_confirmation_successful')
    redirect_to after_confirmation_path
  end

  def check_for_unconfirmed_phone
    redirect_to root_path unless unconfirmed_phone
  end

  def send_confirmation_code
    # Generate a new confirmation code only if there isn't already one set in the
    # user's session. Re-sending the confirmation code doesn't generate a new one.
    self.confirmation_code = generate_confirmation_code unless confirmation_code

    job = "#{current_otp_method.to_s.capitalize}SenderOtpJob".constantize

    job.perform_later(confirmation_code, unconfirmed_phone)

    flash[:success] = t("notices.send_code.#{current_otp_method}")
  end

  def set_fallback_vars
    @fallback_confirmation_link = fallback_confirmation_link
    @sms_enabled = sms_enabled?
    @current_otp_method = current_otp_method
  end

  def fallback_confirmation_link
    if sms_enabled?
      this_send_confirmation_code_path(:voice)
    else
      this_send_confirmation_code_path(:sms)
    end
  end

  def confirmation_code=(code)
    user_session[confirmation_code_session_key] = code
  end

  def confirmation_code
    user_session[confirmation_code_session_key]
  end

  def unconfirmed_phone
    user_session[unconfirmed_phone_session_key]
  end

  def clear_session_data
    user_session.delete(unconfirmed_phone_session_key)
    user_session.delete(confirmation_code_session_key)
  end

  def sms_enabled?
    current_otp_method == :sms
  end

  def current_otp_method
    query_method = params[:otp_method]

    return :sms unless %w(sms voice totp).include? query_method

    query_method.to_sym
  end
end
