module RememberDeviceConcern
  extend ActiveSupport::Concern

  def save_remember_device_preference
    return unless params[:remember_device] == 'true'
    cookies.encrypted[:remember_device] = RememberDeviceCookie.new(
      user_id: current_user.id,
      created_at: Time.zone.now
    ).to_json
  end

  def check_remember_device_preference
    return unless authentication_context?
    return if remember_device_cookie.nil?
    return unless remember_device_cookie.valid_for_user?(current_user)
    handle_valid_otp_for_authentication_context
  end

  def remember_device_cookie
    remember_device_cookie_contents = cookies.encrypted[:remember_device]
    return if remember_device_cookie_contents.blank?
    @remember_device_cookie ||= RememberDeviceCookie.from_json(
      remember_device_cookie_contents
    )
  end
end
