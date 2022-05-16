module Funnel
  module DocAuth
    class RegisterStepFromAnalyticsViewEvent
      ANALYTICS_EVENT_TO_DOC_AUTH_LOG_TOKEN = {
        'IdV: phone of record visited' => :verify_phone,
        'IdV: review info visited' => :encrypt,
        'IdV: final resolution' => :verified,
        'IdV: USPS address visited' => :usps_address,
      }.freeze

      def self.call(user_id, issuer, event, result)
        token = ANALYTICS_EVENT_TO_DOC_AUTH_LOG_TOKEN[event]
        Funnel::DocAuth::RegisterStep.new(user_id, issuer).call(token, :view, result) if token
      end
    end
  end
end
