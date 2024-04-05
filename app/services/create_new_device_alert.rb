# frozen_string_literal: true

class CreateNewDeviceAlert < ApplicationJob
  queue_as :long_running

  def perform(now)
    emails_sent = 0
    User.where(
      sql_query_for_users_with_new_device,
      tvalue: now - IdentityConfig.store.new_device_alert_delay_in_minutes.minutes,
    ).each do |user|
      emails_sent += 1 if UserAlerts::AlertUserAboutNewDevice.send_alert(user)
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
end
