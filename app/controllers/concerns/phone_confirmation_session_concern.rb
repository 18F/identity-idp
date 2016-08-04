# Methods related to storing and clearing session variables used
# in PhoneConfirmationController

module PhoneConfirmationSessionConcern
  extend ActiveSupport::Concern

  def confirmation_code=(code)
    user_session[:phone_confirmation_code] = code
  end

  def confirmation_code
    user_session[:phone_confirmation_code]
  end

  def unconfirmed_phone
    user_session[:unconfirmed_phone]
  end

  def unconfirmed_phone_sms_enabled?
    user_session[:unconfirmed_phone_sms_enabled]
  end

  def clear_session_data
    user_session.delete(:unconfirmed_phone)
    user_session.delete(:unconfirmed_phone_sms_enabled)
    user_session.delete(:phone_confirmation_code)
  end
end
