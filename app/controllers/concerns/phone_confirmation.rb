module PhoneConfirmation
  def prompt_to_confirm_mobile(form)
    user_session[:unconfirmed_mobile] = form.mobile
    user_session[:unconfirmed_mobile_taken] = form.mobile_taken?
    redirect_to phone_confirmation_send_path
  end
end
