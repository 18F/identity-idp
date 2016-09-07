# Methods related to fallback support during two factor authentication
# eg. confirm with Voice OTP when first choice was SMS and
#  		SMS when first choice was Voice OTP

module OtpDeliveryFallback
  extend ActiveSupport::Concern

  included do
    before_action :set_fallback_vars, only: :confirm
  end

  def fallback_confirmation_link
    if sms_enabled?
      otp_send_path(otp_method: :voice)
    else
      otp_send_path(otp_method: :sms)
    end
  end

  def set_fallback_vars
    @fallback_confirmation_link = fallback_confirmation_link
    @sms_enabled = sms_enabled?
    @current_otp_method = current_otp_method
  end

  def sms_enabled?
    current_otp_method == :sms
  end

  def current_otp_method
    query_method = params[:otp_method]
    return query_method.to_sym if %w(sms voice totp rescue_code).include? query_method
    return :totp if current_user.totp_enabled?
    return :sms
  end
end
