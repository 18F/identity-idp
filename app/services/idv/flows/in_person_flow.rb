module Idv
  module Flows
    class InPersonFlow < Flow::BaseFlow
      STEPS = {
        location: Idv::Steps::Ipp::LocationStep,
        welcome: Idv::Steps::Ipp::WelcomeStep,  # instructions
        address: Idv::Steps::Ipp::AddressStep,  # entering the address
        state_id: Idv::Steps::Ipp::StateIdStep, # info from state id
        ssn: Idv::Steps::Ipp::SsnStep, # enter SSN
        # todo: add the failure branch for verify step
        verify: Idv::Steps::Ipp::VerifyStep, # verify entered info
        # todo: add the verify by mail flow
        # todo: add the failure branch for phone step
        phone: Idv::Steps::Ipp::PhoneStep, # phone finder
        # todo: re-use existing password confirm step
        password_confirm: Idv::Steps::Ipp::PasswordConfirmStep,
        # todo: re-use existing personal key step
        personal_key: Idv::Steps::Ipp::PersonalKeyStep,
        barcode: Idv::Steps::Ipp::BarcodeStep,
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
