class CreateNewDeviceAlert < ApplicationJob
  queue_as :long_running

  def perform(now)
    emails_sent = 0
    User.where(
      sql_query_for_users_with_new_device,
      tvalue: now - IdentityConfig.store.new_device_alert_delay_in_minutes.minutes,
    ).each do |user|
      emails_sent += 1 if clear_new_device_and_send_email(user)
    end

    emails_sent
  end

  private

  def sql_query_for_users_with_new_device
    <<~SQL
      sign_in_new_device_at < :tvalue AND
      sign_in_new_device_at IS NOT NULL
    SQL
  end

  def clear_new_device_and_send_email(user)
    user.sign_in_new_device_at = nil
    user.save
    # user_devices = user.recent_devices
    # user_events = user.recent_events
    # location = user_devices.last.last_sign_in_location_and_ip
    # disavowal_token = SecureRandom.urlsafe_base64(32)

    # user.confirmed_email_addresses.each do |email_address|
    #   UserMailer.with(user: user, email_address: email_address).new_device_sign_in(
    #     date: user_devices.last.last_used_at.in_time_zone('Eastern Time (US & Canada)').
    #       strftime('%B %-d, %Y %H:%M Eastern Time'),
    #     location: location,
    #     devices: user_devices,
    #     events: user_events,
    #     disavowal_token: disavowal_token,
    #   ).deliver_now_or_later
    # end
    true
  end
end
