class UserEventCreator
  COOKIE_LENGTH = 128

  attr_reader :request, :current_user

  def initialize(current_user:, request: nil)
    @request = request
    @current_user = current_user
  end

  # @return [Array(Event, String)] an (event, disavowal_token) tuple
  def create_user_event(event_type, user = current_user, disavowal_token = nil)
    return unless user&.id
    existing_device = Device.find_by(user_id: user.id, cookie_uuid: cookies[:device])
    if existing_device.present?
      create_event_for_existing_device(
        event_type: event_type,
        user: user,
        device: existing_device,
        disavowal_token: disavowal_token,
      )
    else
      create_event_for_new_device(
        event_type: event_type,
        user: user,
        disavowal_token: disavowal_token,
      )
    end
  end

  # Create an event without a device or IP address
  # @return [Array(Event, String)] an (event, disavowal_token) tuple
  def create_out_of_band_user_event(event_type)
    create_event_for_device(event_type: event_type, user: current_user, device: nil)
  end

  # @return [Array(Event, String)] an (event, disavowal_token) tuple
  def create_user_event_with_disavowal(event_type, user = current_user, device = nil)
    disavowal_token = SecureRandom.urlsafe_base64(32)
    if device
      create_event_for_existing_device(
        event_type: event_type,
        user: user,
        device: device,
        disavowal_token: disavowal_token,
      )
    else
      create_user_event(event_type, user, disavowal_token)
    end
  end

  private

  # @return [Array(Event, String)] an (event, disavowal_token) tuple
  def create_event_for_existing_device(event_type:, user:, device:, disavowal_token:)
    device.update_last_used_ip(request.remote_ip)
    create_event_for_device(
      event_type: event_type,
      user: user,
      device: device,
      disavowal_token: disavowal_token,
    )
  end

  # @return [Array(Event, String)] an (event, disavowal_token) tuple
  def create_event_for_new_device(event_type:, user:, disavowal_token:)
    user_has_multiple_devices = UserDecorator.new(user).devices?

    device = create_device_for_user(user)
    if user_has_multiple_devices && disavowal_token.nil?
      event, disavowal_token = create_user_event_with_disavowal(
        event_type, user, device
      )
      send_new_device_notification(
        user: user,
        device: device,
        disavowal_token: disavowal_token,
      )
      [event, disavowal_token]
    else
      create_event_for_device(
        device: device,
        event_type: event_type,
        user: user,
        disavowal_token: disavowal_token,
      )
    end
  end

  def create_device_for_user(user)
    cookie_uuid = cookies[:device].presence || SecureRandom.hex(COOKIE_LENGTH / 2)

    device = Device.create!(
      user: user,
      user_agent: request.user_agent.to_s,
      cookie_uuid: cookie_uuid,
      last_used_at: Time.zone.now,
      last_ip: request.remote_ip,
    )
    assign_device_cookie(device.cookie_uuid)
    device
  end

  def assign_device_cookie(device_cookie)
    cookies.permanent[:device] = device_cookie unless device_cookie == cookies[:device]
  end

  def send_new_device_notification(user:, device:, disavowal_token:)
    UserAlerts::AlertUserAboutNewDevice.call(user, device, disavowal_token)
  end

  # @return [Array(Event, String)] an (event, disavowal_token) tuple
  def create_event_for_device(event_type:, user:, device:, disavowal_token: nil)
    disavowal_token_fingerprint = if disavowal_token
                                    Pii::Fingerprinter.fingerprint(disavowal_token)
                                  end
    event = Event.create(
      user_id: user.id,
      device_id: device&.id,
      ip: request&.remote_ip,
      event_type: event_type,
      disavowal_token_fingerprint: disavowal_token_fingerprint,
    )

    [event, disavowal_token]
  end

  def cookies
    request.cookie_jar
  end
end
