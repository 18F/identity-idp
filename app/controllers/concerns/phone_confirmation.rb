module PhoneConfirmation
  def prompt_to_confirm_phone(phone, phone_sms_enabled)
    user_session[:unconfirmed_phone] = phone
    user_session[:unconfirmed_phone_sms_enabled] = phone_sms_enabled
    redirect_to phone_confirmation_send_path
  end
end
