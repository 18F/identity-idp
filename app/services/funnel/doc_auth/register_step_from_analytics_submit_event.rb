module Funnel
  module DocAuth
    class RegisterStepFromAnalyticsSubmitEvent
      ANALYTICS_EVENT_TO_DOC_AUTH_LOG_TOKEN = {
        Analytics::IDV_GPO_ADDRESS_LETTER_REQUESTED => :usps_letter_sent,
        'IdV: phone confirmation form' => :verify_phone,
      }.freeze

      def self.call(user_id, issuer, event, result)
        token = ANALYTICS_EVENT_TO_DOC_AUTH_LOG_TOKEN[event]
        return unless token
        Funnel::DocAuth::RegisterStep.new(user_id, issuer).call(token, :update, result)
      end
    end
  end
end
