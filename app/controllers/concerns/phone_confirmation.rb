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
    phone_number = user_session[:unconfirmed_phone]
    @otp_delivery_selection_form = OtpDeliverySelectionForm.new(current_user)

    @presenter = TwoFactorAuthCode::OtpDeliveryPresenter.new(
      reenter_phone_number_path: manage_phone_path,
      phone_number: phone_number,
      unconfirmed_phone: phone_number && confirmation_context?,
      recovery_code_unavailable: idv_or_confirmation_context?
    )
    render 'users/two_factor_authentication/show'
  end
end
