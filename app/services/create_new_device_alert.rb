class CreateNewDeviceAlert < ApplicationJob
  queue_as :long_running

  def perform
    User.where(
      'sign_in_new_device < ?', IdentityConfig.store.new_device_alert_delay_in_minutes.minutes.ago
    ).each do |user|
      email_and_clear(user)
    end
  end

  private

  def email_and_clear(user)
    user.sign_in_new_device = nil
    user.save

    # user_devices = user.recent_devices
    # user_events = user.recent_events

    # user.confirmed_email_addresses.each do |email_address, user_devices, user_events|
    #   UserMailer.with(user: user, email_address: email_address).new_device_sign_in(
    #     date: device.last_used_at.in_time_zone('Eastern Time (US & Canada)').
    #       strftime('%B %-d, %Y %H:%M Eastern Time'),
    #     location: login_location,
    #     devices: user_devices,
    #     events: user_events,
    #     disavowal_token: disavowal_token,
    #   ).deliver_now_or_later
    # end
  end
end
