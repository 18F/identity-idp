module Idv
  module Flows
    class CacFlow < Flow::BaseFlow
      STEPS = {
        choose_method: Idv::Steps::Cac::ChooseMethodStep,
        welcome: Idv::Steps::Cac::WelcomeStep,
        present_cac: Idv::Steps::Cac::PresentCacStep,
        enter_info: Idv::Steps::Cac::EnterInfoStep,
        verify: Idv::Steps::Cac::VerifyStep,
        verify_wait: Idv::Steps::Cac::VerifyWaitStep,
      }.freeze

      OPTIONAL_SHOW_STEPS = {
        verify_wait: Idv::Steps::Cac::VerifyWaitStepShow,
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
