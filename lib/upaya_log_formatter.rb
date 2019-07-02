# frozen_string_literal: true

module Upaya
  class UpayaLogFormatter < ::Logger::Formatter
    # This method is invoked when a log event occurs
    def call(severity, timestamp, progname, msg)
      # If message looks like JSON, print it directly. This is a hack to avoid
      # needing to change the analytics ETL Lambdas that parse the pageview
      # JSON logs.
      # If the Analytics ETL lambda is no longer in use or has had more
      # sophisticated parsing added, then this could be removed.
      if msg.is_a?(String) && msg.start_with?('{') && msg.end_with?('}')
        "#{msg}\n"
      else
        # Otherwise, use default Ruby log format
        super
      end
    end
  end

  class DevelopmentUpayaLogFormatter < UpayaLogFormatter
    # This method is invoked when a log event occurs
    def call(severity, timestamp, progname, msg)
      # If message contains terminal escapes, print it directly. This is useful
      # in development because rails dev logs contain SQL queries with ANSI
      # terminal escapes that should be printed as-is without timestamps.
      if msg.is_a?(String) && msg.include?("\u001b[")
        "#{msg}\n"
      else
        # Otherwise, see parent
        super
      end
    end
  end
end
