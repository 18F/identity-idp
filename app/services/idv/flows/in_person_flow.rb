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
      end

      def self.session_idv(session)
        session[:idv] ||= { params: {}, step_attempts: { phone: 0 } }
        # WILLFIX: remove this block when we begin collecting user data
        session[:idv][:applicant] ||= {
          first_name: 'Susan',
          last_name: 'Smith',
          middle_name: 'Q',
          address1: '1 Microsoft Way',
          address2: 'Apt 3',
          city: 'Bayside',
          state: 'NY',
          zipcode: '11364',
          dob: '1938-10-06',
          ssn: '900123123',
        }

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
