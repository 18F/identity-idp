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
      }.freeze

      ACTIONS = {
      }.freeze

      # WILLFIX: (LG-6308) move this to the barcode page when we finish setting up IPP step
      # indicators
      # i18n-tasks-use t('step_indicator.flows.idv.go_to_the_post_office')

      STEP_INDICATOR_STEPS = [
        { name: :find_a_post_office },
        { name: :verify_info },
        { name: :verify_phone_or_address },
        { name: :secure_account },
        { name: :go_to_the_post_office },
      ].freeze

      def initialize(controller, session, name)
        @idv_session = self.class.session_idv(session)
        super(controller, STEPS, ACTIONS, session[name])
        # WILLFIX: remove this when we are collecting these values from the user
        @flow_session ||= {}
        @flow_session[:pii_from_user] ||= Idp::Constants::MOCK_IDV_APPLICANT.dup
      end

      def self.session_idv(session)
        session[:idv] ||= { params: {}, step_attempts: { phone: 0 } }

        # WILLFIX: remove this line when we begin collecting user data
        session[:idv][:applicant] ||= Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN

        # WILLFIX: (LG-6349) remove this block when we implement the verify page
        session[:idv]['profile_confirmation'] = true
        session[:idv]['vendor_phone_confirmation'] = false
        session[:idv]['user_phone_confirmation'] = false
        session[:idv]['address_verification_mechanism'] = 'phone'
        session[:idv]['resolution_successful'] = 'phone'
      end
    end
  end
end
