class DeviceCookie
  def self.check_for_new_device(cookies, user)
    return unless user&.id
    cookies[:device] && Device.find_by(
      user_id: user.id,
      cookie_uuid: cookies[:device],
    )
  end
end
