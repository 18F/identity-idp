# frozen_string_literal: true

class CreateNewDeviceAlertJob < ApplicationJob
  queue_as :long_running

  def perform(now)
    emails_sent = 0
    User.where(
      sql_query_for_users_with_new_device,
      tvalue: now - IdentityConfig.store.new_device_alert_delay_in_minutes.minutes,
    ).limit(2_000).find_each(batch_size: 100) do |user|
      emails_sent += 1 if expire_sign_in_notification_timeframe_and_send_alert(user)
    end

    analytics.create_new_device_alert_job_emails_sent(count: emails_sent)

    emails_sent
  end

  private

  def analytics
    @analytics ||= Analytics.new(user: AnonymousUser.new, request: nil, sp: nil, session: {})
  end

  def sql_query_for_users_with_new_device
    <<~SQL
      sign_in_new_device_at IS NOT NULL AND
      sign_in_new_device_at < :tvalue
    SQL
  end

  def expire_sign_in_notification_timeframe_and_send_alert(user)
    disavowal_event, disavowal_token = UserEventCreator.new(current_user: user)
      .create_out_of_band_user_event_with_disavowal(:sign_in_notification_timeframe_expired)

    UserAlerts::AlertUserAboutNewDevice.send_alert(user:, disavowal_event:, disavowal_token:)
  end
end
