namespace :reset_device do
  desc 'Send Notifications'
  task send_notifications: :environment do
    users_sql = <<~SQL
      cancelled_at IS NULL AND
      granted_at IS NULL AND
      requested_at < :tvalue AND
      request_token IS NOT NULL AND
      granted_token IS NULL
    SQL
    ChangePhoneRequest.where(
      users_sql, tvalue: Time.zone.now - FeatureManagement.reset_device_wait_period_days.days
    ).order('requested_at ASC').each do |cpr|
      user = cpr.user
      ResetDevice.new(user).grant_request
      SmsResetDeviceNotifierJob.perform_now(
        phone: user.phone,
        cancel_token: cpr.request_token
      )
      UserMailer.reset_device_granted(user, cpr).deliver_later
    end
  end

  desc 'Troubleshoot User Given Email'
  task :troubleshoot, [:email] => [:environment] do |_t, args|
    Rails.logger = Logger.new(STDOUT)
    email = args[:email]
    user = User.find_with_email(email)
    unless user
      Rails.logger.info('User not found')
      return
    end
    cpr = user.change_phone_request
    if cpr
      Rails.logger.info(
        <<~REPORT
          Last Phone Change Request:
          requested_at: #{cpr.requested_at&.localtime}
          request_token: #{cpr.request_token ? 'present' : nil}
          request_count: #{cpr.request_count}
          cancelled_at: #{cpr.cancelled_at&.localtime}
          cancel_count: #{cpr.cancel_count}
          granted_at: #{cpr.granted_at&.localtime}
          granted_token: #{cpr.granted_token ? 'present' : nil}
          security_answer_correct: #{cpr.security_answer_correct}
          wrong_answer_count: #{cpr.wrong_answer_count}
          answered_at: #{cpr.answered_at&.localtime}
          phone_changed_count: #{cpr.phone_changed_count}
          created_at: #{cpr.created_at&.localtime}
          updated_at: #{cpr.updated_at&.localtime}
        REPORT
      )
    else
      Rails.logger.info('Last Phone Change Request: none')
    end
    events = user.events.where(event_type: 'phone_changed').map do |event|
      event.created_at.localtime
    end
    events.sort! { |a, b| b <=> a }
    Rails.logger.info("Phone Change Events: #{events.inspect}")
  end
end
