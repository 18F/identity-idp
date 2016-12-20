module PhoneConfirmation
  def prompt_to_confirm_phone(phone:, otp_method: nil, context: 'confirmation')
    user_session[:unconfirmed_phone] = phone
    user_session[:context] = context
    # If the user selected delivery method, the code is sent and user is
    # prompted to confirm.
    prompt_to_choose_delivery_method and return unless otp_method

    redirect_to otp_send_path(
      otp_delivery_selection_form: { otp_method: otp_method }
    )
  end

  def prompt_to_choose_delivery_method
    @phone_number = user_session[:unconfirmed_phone]
    @otp_delivery_selection_form = OtpDeliverySelectionForm.new
    render 'users/two_factor_authentication/show'
  end
end
