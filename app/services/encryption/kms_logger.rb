# frozen_string_literal: true

module Encryption
  class KmsLogger
    def self.log(action:, timestamp:, key_id:, context: nil, log_context: nil)
      output = {
        kms: {
          timestamp: timestamp,
          action: action,
          encryption_context: context,
          log_context: log_context,
          key_id: key_id,
        },
        log_filename: Idp::Constants::KMS_LOG_FILENAME,
      }

      logger.info(output.to_json)
    end

    def self.logger
      Rails.application.config.kms_logger
    end
  end
end
