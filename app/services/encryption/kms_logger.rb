module Encryption
  class KmsLogger
    LOG_FILENAME = 'kms.log'
    def self.log(action, key_id:, context: nil)
      output = {
        kms: {
          action: action,
          encryption_context: context,
          key_id: key_id,
        },
        log_filename: LOG_FILENAME,
      }
      logger.info(output.to_json)
    end

    def self.logger
      @logger ||= if FeatureManagement.log_to_stdout?
                    Logger.new(STDOUT)
                  else
                    Logger.new(Rails.root.join('log', LOG_FILENAME))
                  end
    end
  end
end
