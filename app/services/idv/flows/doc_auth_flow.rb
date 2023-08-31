module Idv
  module Flows
    class DocAuthFlow < Flow::BaseFlow
      STEPS = {}.freeze

      OPTIONAL_SHOW_STEPS = {}.freeze

      ACTIONS = {}.freeze

      attr_reader :idv_session # this is needed to support (and satisfy) the current LOA3 flow

      def initialize(controller, session, name)
        @idv_session = self.class.session_idv(session)
        super(controller, STEPS, ACTIONS, session[name])
      end

      def self.session_idv(session)
        session[:idv] ||= {}
      end

      def extra_analytics_properties
        {
          acuant_sdk_upgrade_ab_test_bucket:
            AbTests::ACUANT_SDK.bucket(flow_session[:document_capture_session_uuid]),
        }
      end
    end
  end
end
