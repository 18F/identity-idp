module Idv
  module Flows
    class InPersonFlow < Flow::BaseFlow
      STEPS = {
        welcome: Idv::Steps::Ipp::WelcomeStep,
        ssn: Idv::Steps::SsnStep,
      }.freeze

      def initialize(controller, session, name)
        @idv_session = self.class.session_idv(session)
        super(controller, STEPS, {}, session[name])
      end

      def self.session_idv(session)
        session[:idv] ||= { params: {}, step_attempts: { phone: 0 } }
      end

      # def flow_session
      #   {}
      # end
    end
  end
end
