module Idv
  module Flows
    class CaptureDocFlow < Flow::BaseFlow
      STEPS = {
        document_capture: Idv::Steps::DocumentCaptureStep,
        capture_complete: Idv::Steps::CaptureCompleteStep,
      }.freeze

      STEP_INDICATOR_STEPS = [
        :getting_started,
        :verify_id,
        :verify_info,
        :verify_phone_or_address,
        :secure_account,
      ].freeze

      ACTIONS = {
        reset: Idv::Actions::ResetAction,
        verify_document: Idv::Actions::VerifyDocumentAction,
        verify_document_status: Idv::Actions::VerifyDocumentStatusAction,
        cancel: Idv::Actions::CancelCaptureDocAction,
      }.freeze

      def initialize(controller, session, _name)
        super(controller, STEPS, ACTIONS, session)
      end

      def flow_path
        'hybrid'
      end
    end
  end
end
