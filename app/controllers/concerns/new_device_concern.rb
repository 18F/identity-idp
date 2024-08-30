# frozen_string_literal: true

module NewDeviceConcern
  def set_new_device_session(new_device)
    if new_device.nil?
      new_device = !current_user.authenticated_device?(cookie_uuid: cookies[:device])
    end

    user_session[:new_device] = new_device
  end

  def new_device?
    user_session[:new_device] != false
  end
end
