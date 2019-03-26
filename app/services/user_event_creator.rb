# :reek:DataClump
class UserEventCreator
  attr_reader :request, :current_user

  def initialize(request, current_user)
    @request = request
    @current_user = current_user
  end

  def create_user_event(event_type, user = current_user)
    return unless user&.id
    existing_device = DeviceTracking::LookupDeviceForUser.call(user.id, cookies[:device])
    if existing_device.present?
      create_event_for_existing_device(event_type: event_type, user: user, device: existing_device)
    else
      create_event_for_new_device(event_type: event_type, user: user)
    end
  end

  def create_user_event_with_disavowal(event_type, user = current_user)
    event = create_user_event(event_type, user)
    EventDisavowal::GenerateDisavowalToken.new(event).call
    event
  end

  private

  def create_event_for_existing_device(event_type:, user:, device:)
    DeviceTracking::UpdateDevice.call(device, request.remote_ip)
    create_event_for_device(event_type: event_type, user: user, device: device)
  end

  def create_event_for_new_device(event_type:, user:)
    user_has_multiple_devices = UserDecorator.new(user).devices?

    device = create_device_for_user(user)
    event = create_event_for_device(device: device, event_type: event_type, user: user)

    return event unless user_has_multiple_devices

    send_new_device_notificaiton(user: user, event: event, device: device)
    event
  end

  def create_device_for_user(user)
    device = DeviceTracking::CreateDevice.call(
      user.id, request.remote_ip, request.user_agent, cookies[:device]
    )
    assign_device_cookie(device.cookie_uuid)
    device
  end

  def assign_device_cookie(device_cookie)
    cookies.permanent[:device] = device_cookie unless device_cookie == cookies[:device]
  end

  def send_new_device_notificaiton(user:, device:, event:)
    disavowal_token = EventDisavowal::GenerateDisavowalToken.new(event).call
    UserAlerts::AlertUserAboutNewDevice.call(user, device, disavowal_token)
  end

  def create_event_for_device(event_type:, user:, device:)
    Event.create(
      user_id: user.id, device_id: device.id, ip: request.remote_ip, event_type: event_type,
    )
  end

  def cookies
    request.cookie_jar
  end
end
