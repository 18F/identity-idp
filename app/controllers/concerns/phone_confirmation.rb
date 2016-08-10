module PhoneConfirmation
  def prompt_to_confirm_phone(phone, sms_otp_delivery)
    user_session[:unconfirmed_phone] = phone
    user_session[:unconfirmed_sms_otp_delivery] = sms_otp_delivery
    redirect_to phone_confirmation_send_path
  end
end
