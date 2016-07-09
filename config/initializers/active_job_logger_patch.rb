# This overrides the ActiveJob logger to remove sensitive info from the logs,
# such as Devise tokens, OTP codes, phone numbers, emails, and data sent to
# Google Analytics.
ActiveSupport.on_load :active_job do
  module ActiveJob
    module Logging
      class LogSubscriber
        private

        def args_info(_job)
          ''
        end
      end
    end
  end
end
