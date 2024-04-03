# frozen_string_literal: true

module Encryption
  class KmsLogger
    def self.log(action, key_id:, context: nil)
      output = {
        kms: {
          action: action,
          encryption_context: context,
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
