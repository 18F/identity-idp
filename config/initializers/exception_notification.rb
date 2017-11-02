require 'exception_notification/rails'
require 'exception_notification/sidekiq'

EXCEPTION_RECIPIENTS = Figaro.env.exception_recipients.split(',').freeze

ExceptionNotification.configure do |config|
  config.add_notifier(
    :email,
    email_prefix: "[#{APP_NAME} EXCEPTION - #{LoginGov::Hostdata.env}] ",
    sender_address: %("Exception Notifier" <notifier@login.gov>),
    exception_recipients: EXCEPTION_RECIPIENTS,
    error_grouping: true,
    sections: %w[request backtrace]
  )
end
