# frozen_string_literal: true

class CreateNewDeviceAlert < ApplicationJob
  queue_as :long_running

  def perform(now)
    emails_sent = 0
    User.where(
      sql_query_for_users_with_new_device,
      tvalue: now - IdentityConfig.store.new_device_alert_delay_in_minutes.minutes,
    ).each do |user|
      emails_sent += 1 if lapse_sign_in_notification_window_and_send_alert(user)
    end

    emails_sent
  end

  private

  def sql_query_for_users_with_new_device
    <<~SQL
      sign_in_new_device_at IS NOT NULL AND
      sign_in_new_device_at < :tvalue
    SQL
  end

  def lapse_sign_in_notification_window_and_send_alert(user)
    disavowal_event, disavowal_token = UserEventCreator.new(current_user: user).
      create_out_of_band_user_event_with_disavowal(:sign_in_notification_window_lapsed)

    UserAlerts::AlertUserAboutNewDevice.send_alert(user:, disavowal_event:, disavowal_token:)
  end
end
