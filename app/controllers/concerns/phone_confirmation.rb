module PhoneConfirmation
  def prompt_to_confirm_phone(phone)
    user_session[:unconfirmed_phone] = phone
    redirect_to phone_confirmation_send_path
  end
end
