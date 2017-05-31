module PhoneConfirmation
  def prompt_to_confirm_phone(phone:, context: 'confirmation')
    user_session[:unconfirmed_phone] = phone
    user_session[:context] = context

    redirect_to otp_send_path(
      otp_delivery_selection_form: { otp_delivery_preference: current_user.otp_delivery_preference }
    )
  end
end
