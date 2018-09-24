module Idv
  module Flows
    class DocAuthFlow < Flow::BaseFlow
      STEPS = {
        ssn: Idv::Steps::SsnStep,
        front_image: Idv::Steps::FrontImageStep,
        back_image: Idv::Steps::BackImageStep,
        doc_failed: Idv::Steps::DocFailedStep,
        doc_success: Idv::Steps::DocSuccessStep,
        self_image: Idv::Steps::SelfImageStep,
      }.freeze

      ACTIONS = {
        reset: Idv::Actions::ResetAction,
      }.freeze

      attr_reader :idv_session # this is needed to support (and satisfy) the current LOA3 flow

      def initialize(session, current_user, name)
        @idv_session = self.class.session_idv(session)
        super(STEPS, ACTIONS, session[name], current_user)
      end

      def self.session_idv(session)
        session[:idv] ||= { params: {}, step_attempts: { phone: 0 } }
      end
    end
  end
end
