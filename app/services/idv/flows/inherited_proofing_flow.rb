module Idv
  module Flows
    class InheritedProofingFlow < Flow::BaseFlow
      STEPS = {
        get_started: Idv::Steps::InheritedProofing::GetStartedStep,
        agreement: Idv::Steps::InheritedProofing::AgreementStep,
        verify_info: Idv::Steps::InheritedProofing::VerifyInfoStep,
        verify_phone: Idv::Steps::InheritedProofing::PhoneStep,
      }.freeze

      STEP_INDICATOR_STEPS = [
        { name: :getting_started },
        { name: :verify_info },
        { name: :verify_phone },
        { name: :secure_account },
      ].freeze

      ACTIONS = {}.freeze

      attr_reader :idv_session # this is needed to support (and satisfy) the current LOA3 flow

      def initialize(controller, session, name)
        @idv_session = self.class.session_idv(session)
        super(controller, STEPS, ACTIONS, session[name])
      end

      def self.session_idv(session)
        session[:idv] ||= {}
      end
    end
  end
end
