module Idv
  module Flows
    class InPersonFlow < Flow::BaseFlow
      STEPS = {
        location: Idv::Steps::Ipp::LocationStep,
        welcome: Idv::Steps::Ipp::WelcomeStep,  # instructions
        address: Idv::Steps::Ipp::AddressStep,  # entering the address
        state_id: Idv::Steps::Ipp::StateIdStep, # info from state id
        ssn: Idv::Steps::Ipp::SsnStep, # enter SSN
        verify: Idv::Steps::Ipp::VerifyStep, # verify entered info
        # WILLFIX: add the failure branch for verify step
        # WILLFIX: add the verify by mail flow
        phone: Idv::Steps::Ipp::PhoneStep, # phone finder
        # WILLFIX: add the failure branch for phone step
        # WILLFIX: re-use existing password confirm step
        password_confirm: Idv::Steps::Ipp::PasswordConfirmStep,
        # WILLFIX: re-use existing personal key step
        personal_key: Idv::Steps::Ipp::PersonalKeyStep,
        barcode: Idv::Steps::Ipp::BarcodeStep,
      }.freeze

      ACTIONS = {
      }.freeze

      STEP_INDICATOR_STEPS = [
        { name: :find_a_post_office },
        { name: :verify_info },
        { name: :verify_phone_or_address },
        { name: :secure_account },
        { name: :go_to_the_post_office },
      ].freeze

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
