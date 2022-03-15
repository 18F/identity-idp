module Idv
  module Flows
    class InPersonFlow < Flow::BaseFlow
      STEPS = {
        welcome: Idv::Steps::Ipp::WelcomeStep,
      }.freeze

      def initialize(controller, session, name)
        @idv_session = self.class.session_idv(session)
        super(controller, STEPS, {}, session[name])
      end

      def self.session_idv(session)
        session[:idv] ||= { params: {}, step_attempts: { phone: 0 } }
      end
    end
  end
end
