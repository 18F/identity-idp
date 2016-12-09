module OtpHelper
  def phone_confirmation_instructions
    if @delivery_method == 'sms'
      t('instructions.2fa.confirm_code_sms', number: @phone_number)
    elsif @delivery_method == 'voice'
      t('instructions.2fa.confirm_code_voice', number: @phone_number)
    end
  end

  def alternative_2fa_links
    case @delivery_method
    when 'sms'
      "#{voice_fallback_link}#{totp_option_link}."
    when 'voice'
      "#{sms_fallback_link}#{get_totp_option_link}."
    when 'recovery-code'
      t('devise.two_factor_authentication.recovery_code_help', phone: phone_fallback_link)
    end
  end

  private

  def totp_option_link
    auth_app_path = link_to(t('devise.two_factor_authentication.totp_name'),
                            login_two_factor_authenticator_path)
    t('links.phone_confirmation.auth_app', link: auth_app_path) if current_user.totp_enabled?
  end

  def phone_fallback_link
    link_to(t('links.phone_confirmation.name'), user_two_factor_authentication_path)
  end

  def voice_fallback_link
    t('links.phone_confirmation.sms_unavailable',
      link: link_to(t('links.phone_confirmation.fallback_to_voice'),
                    otp_send_path(otp_delivery_selection_form: { otp_method: :voice })))
  end

  def sms_fallback_link
    t('links.phone_confirmation.voice_unavailable',
      link: link_to(t('links.phone_confirmation.fallback_to_sms'),
                    otp_send_path(otp_delivery_selection_form: { otp_method: :sms })))
  end
end
