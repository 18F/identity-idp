class DeviceCookie
  def self.check_for_new_device(cookies, current_user)
    cookies[:device] && Device.find_by(
      user_id: current_user.id,
      cookie_uuid: cookies[:device],
    )
  end
end
