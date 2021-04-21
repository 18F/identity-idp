require 'json'
require 'time'
require 'logger'

module IdentityIdpFunctions
  module LoggingHelper
    def log_event(name:, level: Logger::INFO, **key_values)
      int_level = level.is_a?(Integer) ? level : Logger.const_get(level.to_s.upcase)

      payload = { name: name }.merge(key_values)
      logger.log(int_level, payload)
    end

    def logger(io: default_logger_io, level: Logger::INFO)
      @logger ||= Logger.new(io).tap do |logger|
        logger.level = level
        logger.formatter = proc do |severity, datetime, _progname, msg|
          payload = msg.is_a?(Hash) ? msg : { message: msg }

          payload.merge(
            time: datetime.iso8601,
            level: severity,
          ).to_json + "\n"
        end
      end
    end

    # This is just a hook so we can override this in specs to not barf to STDOUT
    def default_logger_io
      STDOUT
    end
  end
end
