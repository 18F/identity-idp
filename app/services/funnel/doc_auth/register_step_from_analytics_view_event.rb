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
        return unless token
        Rails.logger.info(
          {
            name: 'event_to_doc_auth_log_token',
            source: 'original',
            user_id: user_id,
            issuer: issuer,
            token: token,
            action: :view,
            success: result,
          }.to_json,
        )
        Funnel::DocAuth::RegisterStep.new(user_id, issuer).call(token, :view, result)
      end
    end
  end
end
