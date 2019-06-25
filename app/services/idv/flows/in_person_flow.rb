module Idv
  module Flows
    class InPersonFlow < Flow::BaseFlow
      STEPS = {
        welcome: Idv::Steps::Ipp::WelcomeStep,
        find_usps: Idv::Steps::Ipp::FindUspsStep,
        usps_list: Idv::Steps::Ipp::UspsListStep,
        enter_info: Idv::Steps::Ipp::EnterInfoStep,
        verify: Idv::Steps::Ipp::VerifyStep,
        encrypt: Idv::Steps::Ipp::EncryptStep,
        bar_code: Idv::Steps::Ipp::BarCodeStep,
      }.freeze

      ACTIONS = {
        reset: Idv::Actions::ResetAction,
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
