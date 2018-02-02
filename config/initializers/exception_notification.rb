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
    sections: %w[request backtrace session]
  )

  config.ignored_exceptions << 'ActionController::BadRequest'
  config.ignore_if do |exception, _options|
    exception.message.start_with?('string contains null byte')
  end
  config.ignore_if do |exception, _options|
    exception.message.start_with?('invalid byte sequence in UTF-8')
  end
  config.ignore_if do |exception, _options|
    exception.code == 21_614 if exception.respond_to?(:code)
  end
end
