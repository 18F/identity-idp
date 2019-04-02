module Idv
  module Flows
    class CaptureDocFlow < Flow::BaseFlow
      STEPS = {
        mobile_front_image: Idv::Steps::MobileFrontImageStep,
        capture_mobile_back_image: Idv::Steps::CaptureMobileBackImageStep,
        capture_complete: Idv::Steps::CaptureCompleteStep,
      }.freeze

      ACTIONS = {
        reset: Idv::Actions::ResetAction,
      }.freeze

      def initialize(controller, session, _name)
        super(controller, STEPS, ACTIONS, session)
      end
    end
  end
end
