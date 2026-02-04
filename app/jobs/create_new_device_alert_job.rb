# frozen_string_literal: true

class CreateNewDeviceAlertJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :long_running

  good_job_control_concurrency_with(
    total_limit: 1,
    perform_limit: 1,
    key: 'CreateNewDeviceAlertJob',
  )

  def perform(now)
    emails_sent = 0
    users_signing_in_with_new_device(now).limit(1_000).find_each(batch_size: 100) do |user|
      emails_sent += 1 if expire_sign_in_notification_timeframe_and_send_alert(user)
    end

    analytics.create_new_device_alert_job_emails_sent(count: emails_sent)

    emails_sent
  end

  private

  def analytics
    @analytics ||= Analytics.new(user: AnonymousUser.new, request: nil, sp: nil, session: {})
  end

  def users_signing_in_with_new_device(now)
    start_time = if IdentityConfig.store.new_device_alert_window_start_in_minutes.nil?
                   nil
                 else
                   now - IdentityConfig.store.new_device_alert_window_start_in_minutes.minutes
                 end
    end_time = now - IdentityConfig.store.new_device_alert_delay_in_minutes.minutes
    User.where(sign_in_new_device_at: start_time..end_time)
  end

  def expire_sign_in_notification_timeframe_and_send_alert(user)
    disavowal_event, disavowal_token = UserEventCreator.new(current_user: user)
      .create_out_of_band_user_event_with_disavowal(:sign_in_notification_timeframe_expired)

    UserAlerts::AlertUserAboutNewDevice.send_alert(user:, disavowal_event:, disavowal_token:)
  end
end
