module Idv
  module Flows
    class InPersonFlow < Flow::BaseFlow
      STEPS = {
        location: Idv::Steps::Ipp::LocationStep,
        welcome: Idv::Steps::Ipp::WelcomeStep,  # instructions
        address: Idv::Steps::Ipp::AddressStep,  # entering the address
        state_id: Idv::Steps::Ipp::StateIdStep, # info from state id
        ssn: Idv::Steps::SsnStep,               # enter SSN (reused, may need to make our own)
        # verify: Idv::Steps::Ipp::Verify,        # verify entered info
        # phone: Idv::Steps::Ipp::Phone,          # phone finder
        # password_confirm: Idv::Steps::Ipp::PasswordConfirm,
        # personal_key: Idv::Steps::Ipp::PersonalKey,
        barcode: Idv::Steps::Ipp::Barcode,
      }.freeze

      ACTIONS = {
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
