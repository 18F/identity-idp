# frozen_string_literal: true

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
    existing_device = cookies[:device] && Device.find_by(
      user_id: user.id,
      cookie_uuid: cookies[:device],
    )
    if existing_device.present?
      create_event_for_existing_device(
        event_type: event_type, user: user, device: existing_device,
        disavowal_token: disavowal_token
      )
    else
      create_event_for_new_device(
        event_type: event_type, user: user,
        disavowal_token: disavowal_token
      )
    end
  end

  # Create an event without a device or IP address
  # @return [Array(Event, String)] an (event, disavowal_token) tuple
  def create_out_of_band_user_event(event_type)
    create_event_for_device(event_type: event_type, user: current_user, device: nil)
  end

  def create_out_of_band_user_event_with_disavowal(event_type)
    create_event_for_device(
      event_type: event_type,
      user: current_user,
      device: nil,
      disavowal_token: build_disavowal_token,
    )
  end

  # @return [Array(Event, String)] an (event, disavowal_token) tuple
  def create_user_event_with_disavowal(event_type, user = current_user, device = nil)
    if device
      create_event_for_existing_device(
        event_type: event_type, user: user, device: device,
        disavowal_token: build_disavowal_token
      )
    else
      create_user_event(event_type, user, build_disavowal_token)
    end
  end

  private

  # @return [Array(Event, String)] an (event, disavowal_token) tuple
  def create_event_for_existing_device(event_type:, user:, device:, disavowal_token:)
    Device.transaction do
      device.update_last_used_ip(request.remote_ip)
      create_event_for_device(
        event_type: event_type,
        user: user,
        device: device,
        disavowal_token: disavowal_token,
      )
    end
  end

  def build_disavowal_token
    SecureRandom.urlsafe_base64(32)
  end

  # @return [Array(Event, String)] an (event, disavowal_token) tuple
  def create_event_for_new_device(event_type:, user:, disavowal_token:)
    if user.fully_registered? && user.has_devices? && disavowal_token.nil?
      event, disavowal_token = Device.transaction do
        device = create_device_for_user(user)
        create_user_event_with_disavowal(event_type, user, device)
      end
      send_new_device_notification(event:)
      [event, disavowal_token]
    else
      Device.transaction do
        device = create_device_for_user(user)
        create_event_for_device(
          device: device,
          event_type: event_type,
          user: user,
          disavowal_token: disavowal_token,
        )
      end
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

  def send_new_device_notification(event:)
    UserAlerts::AlertUserAboutNewDevice.call(event:)
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
