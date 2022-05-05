module Funnel
  module DocAuth
    class RegisterStepFromAnalyticsViewEvent
      ANALYTICS_EVENT_TO_DOC_AUTH_LOG_TOKEN = {
        Analytics::IDV_PHONE_RECORD_VISIT => :verify_phone,
        Analytics::IDV_REVIEW_VISIT => :encrypt,
        'IdV: final resolution' => :verified,
        Analytics::IDV_GPO_ADDRESS_VISITED => :usps_address,
      }.freeze

      def self.call(user_id, issuer, event, result)
        token = ANALYTICS_EVENT_TO_DOC_AUTH_LOG_TOKEN[event]
        Funnel::DocAuth::RegisterStep.new(user_id, issuer).call(token, :view, result) if token
      end
    end
  end
end
