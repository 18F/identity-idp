module Funnel
  module DocAuth
    class RegisterStepFromAnalyticsViewEvent
      ANALYTICS_EVENT_TO_DOC_AUTH_LOG_TOKEN = {
        Analytics::IDV_PHONE_RECORD_VISIT => :verify_phone,
        Analytics::IDV_REVIEW_VISIT => :encrypt,
        Analytics::IDV_FINAL => :verified,
        Analytics::IDV_USPS_ADDRESS_VISITED => :usps_address,
      }.freeze

      def self.call(user_id, event, result)
        token = ANALYTICS_EVENT_TO_DOC_AUTH_LOG_TOKEN[event]
        Funnel::DocAuth::RegisterStep.call(user_id, token, :view, result) if token
      end
    end
  end
end
