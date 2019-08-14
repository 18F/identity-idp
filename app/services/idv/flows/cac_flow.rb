module Idv
  module Flows
    class CacFlow < Flow::BaseFlow
      STEPS = {
        welcome: Idv::Steps::Cac::WelcomeStep,
        present_cac: Idv::Steps::Cac::PresentCacStep,
        enter_info: Idv::Steps::Cac::EnterInfoStep,
        verify: Idv::Steps::Cac::VerifyStep,
        success: Idv::Steps::Cac::SuccessStep,
      }.freeze

      ACTIONS = {
        reset: Idv::Actions::ResetAction,
        redo_enter_info: Idv::Actions::RedoEnterInfoAction,
      }.freeze

      attr_reader :idv_session # this is needed to support (and satisfy) the current LOA3 flow

      def initialize(controller, session, name)
        @idv_session = self.class.session_idv(session)
        super(controller, STEPS, ACTIONS, session[name])
      end

      def self.session_idv(session)
        session[:idv] ||= { params: {}, step_attempts: { phone: 0 } }
      end
    end
  end
end
