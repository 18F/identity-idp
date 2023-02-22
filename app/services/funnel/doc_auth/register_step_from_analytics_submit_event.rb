module Funnel
  module DocAuth
    class RegisterStepFromAnalyticsSubmitEvent
      ANALYTICS_EVENT_TO_DOC_AUTH_LOG_TOKEN = {
        'IdV: USPS address letter requested' => :usps_letter_sent,
        'IdV: phone confirmation form' => :verify_phone,
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
            action: :update,
            success: result,
          }.to_json,
        )
        Funnel::DocAuth::RegisterStep.new(user_id, issuer).call(token, :update, result)
      end
    end
  end
end
