# frozen_string_literal: true

module NewDeviceConcern
  def set_new_device_session
    user_session[:new_device] = !current_user.authenticated_device?(cookie_uuid: cookies[:device])
  end

  def new_device?
    user_session[:new_device] != false
  end
end
