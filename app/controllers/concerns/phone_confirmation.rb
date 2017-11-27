module PhoneConfirmation
  def prompt_to_confirm_phone(phone:, context: 'confirmation', selected_delivery_method: nil)
    user_session[:unconfirmed_phone] = phone
    user_session[:context] = context

    redirect_to otp_send_url(
      otp_delivery_selection_form: {
        otp_delivery_preference: otp_delivery_method(phone, selected_delivery_method),
      }
    )
  end

  private

  def otp_delivery_method(phone, selected_delivery_method)
    return :sms if PhoneNumberCapabilities.new(phone).sms_only?
    return selected_delivery_method if selected_delivery_method.present?
    current_user.otp_delivery_preference
  end
end
