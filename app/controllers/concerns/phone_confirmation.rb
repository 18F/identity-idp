module PhoneConfirmation
  def prompt_to_confirm_mobile(mobile)
    user_session[:unconfirmed_mobile] = mobile
    redirect_to phone_confirmation_send_path
  end
end
