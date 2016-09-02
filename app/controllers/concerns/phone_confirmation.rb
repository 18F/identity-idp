module PhoneConfirmation
  def prompt_to_confirm_phone(phone, otp_method = nil)
    user_session[:unconfirmed_phone] = phone
    # If the user selected delivery method, the code is sent and user is
    # prompted to confirm.
    prompt_to_choose_delivery_method and return unless otp_method

    redirect_to phone_confirmation_send_path(
      otp_method: otp_method
    )
  end

  def prompt_to_choose_delivery_method
    @phone_number = user_session[:unconfirmed_phone]
    render 'shared/choose_delivery_method'
  end
end
