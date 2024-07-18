# frozen_string_literal: true

module NewDeviceConcern
  def set_new_device_session(new_device)
    if new_device.nil?
      new_device = !current_user.authenticated_device?(cookie_uuid: cookies[:device])
    end

    user_session[:new_device] = new_device
  end

  # @return [Boolean,nil] Whether current user session is from a new device. Returns nil if there is
  # no active user session.
  def new_device?
    return nil unless warden.authenticated?(:user)
    user_session[:new_device] != false
  end
end
