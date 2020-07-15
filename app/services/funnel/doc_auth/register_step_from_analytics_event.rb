module Funnel
  module DocAuth
    class RegisterStepFromAnalyticsEvent
      def self.call(user_id, issuer, event, result)
        RegisterStepFromAnalyticsSubmitEvent.call(user_id, issuer, event, result)
        RegisterStepFromAnalyticsViewEvent.call(user_id, issuer, event, result)
      end
    end
  end
end
