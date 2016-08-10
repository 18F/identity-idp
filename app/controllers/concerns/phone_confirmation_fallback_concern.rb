# Methods related to fallback support during phone confirmation
# eg. confirm with Voice OTP when first choice was SMS and
#  		SMS when first choice was Voice OTP

module PhoneConfirmationFallbackConcern
  extend ActiveSupport::Concern

  included do
    before_action :set_fallback_vars, only: :show
  end

  def fallback_confirmation_link
    if user_session[:unconfirmed_sms_otp_delivery]
      phone_confirmation_disable_sms_path
    else
      phone_confirmation_enable_sms_path
    end
  end

  def disable_sms
    user_session[:unconfirmed_sms_otp_delivery] = false
    send_code
  end

  def enable_sms
    user_session[:unconfirmed_sms_otp_delivery] = true
    send_code
  end

  def set_fallback_vars
    @fallback_confirmation_link = fallback_confirmation_link
    @sms_enabled = unconfirmed_sms_otp_delivery?
  end
end
