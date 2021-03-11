module Idv
  module Flows
    class CaptureDocFlow < Flow::BaseFlow
      STEPS = {
        document_capture: Idv::Steps::DocumentCaptureStep,
        capture_complete: Idv::Steps::CaptureCompleteStep,
      }.freeze

      ACTIONS = {
        reset: Idv::Actions::ResetAction,
        verify_document: Idv::Actions::VerifyDocumentAction,
        verify_document_status: Idv::Actions::VerifyDocumentStatusAction,
        cancel: Idv::Actions::CancelCaptureDocAction,
      }.freeze

      def initialize(controller, session, _name)
        super(controller, STEPS, ACTIONS, session)
      end
    end
  end
end
