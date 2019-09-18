module Funnel
  module DocAuth
    class RegisterStepFromAnalyticsEvent
      def self.call(user_id, event, result)
        RegisterStepFromAnalyticsSubmitEvent.call(user_id, event, result)
        RegisterStepFromAnalyticsViewEvent.call(user_id, event, result)
      end
    end
  end
end
