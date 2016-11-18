logger = Logger.new("#{Rails.root}/log/events.log")

logger.formatter = lambda do |_severity, timestamp, _app_name, message|
  message[:timestamp] = timestamp
  "#{::JSON.dump(message)}\n"
end

ANALYTICS_LOGGER = logger
