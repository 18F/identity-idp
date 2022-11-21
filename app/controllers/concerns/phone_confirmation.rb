module PhoneConfirmation
  def prompt_to_confirm_phone(id:, phone:, selected_delivery_method: nil,
                              selected_default_number: nil, phone_type: nil)

    # TODO: Why is selected_default_number not used?
    user_session[:unconfirmed_phone] = phone
    user_session[:context] = 'confirmation'
    user_session[:phone_type] = phone_type

    # otp_send GET             (/:locale)/otp/send(.:format)                                        users/two_factor_authentication#send_code {:locale=>/en|es|fr/}
    redirect_to otp_send_url(
      otp_delivery_selection_form: {
        otp_delivery_preference: otp_delivery_method(id, phone, selected_delivery_method),
        otp_make_default_number: selected_default_number,
      },
    )
  end

  private

  def otp_delivery_method(_id, phone, selected_delivery_method)
    capabilities = PhoneNumberCapabilities.new(phone, phone_confirmed: false)
    return :sms if capabilities.sms_only?
    return selected_delivery_method if selected_delivery_method.present?
    current_user.otp_delivery_preference
  end
end
