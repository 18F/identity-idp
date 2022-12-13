module RequestHelper
  VALID_PASSWORD = 'Val!d Pass w0rd'.freeze

  def user_with_2fa
    create(:user, :signed_up, with: { phone: '+1 202-555-1212' }, password: VALID_PASSWORD)
  end

  def sign_in_user(user = user_with_2fa)
    post new_user_session_path, params: { user: { email: user.email, password: user.password } }
    get otp_send_path, params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }
    follow_redirect!
    post login_two_factor_path,
         params: {
           otp_delivery_preference: 'sms', code: user.reload.direct_otp
         }
  end
end

RSpec.configure do |config|
  config.include RequestHelper, type: :request
end
