module PhoneConfirmation
  def prompt_to_confirm_phone(phone:, context: 'confirmation')
    user_session[:unconfirmed_phone] = phone
    user_session[:context] = context

    redirect_to otp_send_path(
      otp_delivery_selection_form: { otp_delivery_preference: otp_delivery_method(phone) }
    )
  end

  private

  def otp_delivery_method(phone)
    if PhoneNumberCapabilities.new(phone).sms_only?
      :sms
    else
      current_user.otp_delivery_preference
    end
  end
end
