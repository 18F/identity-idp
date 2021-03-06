require 'exception_notification/rails'

EXCEPTION_RECIPIENTS = IdentityConfig.store.exception_recipients

ExceptionNotification.configure do |config|
  config.add_notifier(
    :email,
    email_prefix: "[#{Identity::Hostdata.domain} EXCEPTION - #{Identity::Hostdata.env}] ",
    sender_address: %("Exception Notifier" <notifier@#{Identity::Hostdata.domain}>),
    exception_recipients: EXCEPTION_RECIPIENTS,
    error_grouping: true,
    sections: %w[request backtrace session],
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
