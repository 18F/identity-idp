class UserEventCreator
  attr_reader :request, :current_user

  def initialize(request, current_user)
    @request = request
    @current_user = current_user
  end

  def create_user_event(event_type, user = current_user)
    return unless user&.id
    device = create_or_update_device(user)
    Event.create(user_id: user.id,
                 device_id: device.id,
                 ip: request.remote_ip,
                 event_type: event_type)
  end

  def create_user_event_with_disavowal(event_type, user = current_user)
    event = create_user_event(event_type, user)
    EventDisavowal::GenerateDisavowalToken.new(event).call
    event
  end

  private

  def create_or_update_device(user)
    cookie = cookies[:device]
    device = DeviceTracking::FindOrCreateDevice.call(
      user, cookie, request.remote_ip, request.user_agent
    )

    device_cookie_uuid = device.cookie_uuid

    cookies.permanent[:device] = device_cookie_uuid unless device_cookie_uuid == cookie
    device
  end

  def cookies
    request.cookie_jar
  end
end
