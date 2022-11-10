module Idv
  module Flows
    class CaptureDocFlow < Flow::BaseFlow
      STEPS = {
        document_capture: Idv::Steps::DocumentCaptureStep,
        capture_complete: Idv::Steps::CaptureCompleteStep,
      }.freeze

      STEP_INDICATOR_STEPS = [
        { name: :getting_started },
        { name: :verify_id },
        { name: :verify_info },
        { name: :verify_phone_or_address },
        { name: :secure_account },
      ].freeze

      ACTIONS = {
        verify_document_status: Idv::Actions::VerifyDocumentStatusAction,
      }.freeze

      def initialize(controller, session, _name)
        super(controller, STEPS, ACTIONS, session)
      end

      def flow_path
        'hybrid'
      end

      def extra_analytics_properties
        bucket = AbTests::NATIVE_CAMERA.bucket(flow_session[:document_capture_session_uuid])

        {
          native_camera_a_b_testing_enabled:
            IdentityConfig.store.idv_native_camera_a_b_testing_enabled,
          native_camera_only: (bucket == :native_camera_only),
        }
      end
    end
  end
end
