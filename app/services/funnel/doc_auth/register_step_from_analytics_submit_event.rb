module Funnel
  module DocAuth
    class RegisterStepFromAnalyticsSubmitEvent
      ANALYTICS_EVENT_TO_DOC_AUTH_LOG_TOKEN = {
        Analytics::IDV_USPS_ADDRESS_LETTER_REQUESTED => :usps_letter_sent,
      }.freeze

      def self.call(user_id, event, result)
        token = ANALYTICS_EVENT_TO_DOC_AUTH_LOG_TOKEN[event]
        return unless token
        Funnel::DocAuth::RegisterStep.call(user_id, token, :update, result == 'success')
      end
    end
  end
end
