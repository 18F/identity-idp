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

      def initialize(session, current_user, _name)
        super(STEPS, ACTIONS, session, current_user)
      end
    end
  end
end
