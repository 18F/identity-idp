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

      attr_reader :idv_session, :va_inherited_proofing_auth_code

      def initialize(controller, session, name)
        @idv_session = self.class.session_idv(session)
        super(controller, STEPS, ACTIONS, session[name])

        # TODO: Verify. Compare app/services/idv/flows/in_person_flow.rb
        @flow_session ||= {}
        # TODO: current_user is nil when this is hit!
        @flow_session[:pii_from_user] ||= { uuid: current_user.uuid }
        applicant = @idv_session['applicant'] || {}
        @flow_session[:pii_from_user] = @flow_session[:pii_from_user].to_h.merge(applicant)
        @va_inherited_proofing_auth_code = @controller.va_inherited_proofing_auth_code
        Rails.logger.debug "xyzzy: @va_inherited_proofing_auth_code: #{@va_inherited_proofing_auth_code}"
      end

      def self.session_idv(session)
        session[:idv] ||= {}
      end
    end
  end
end
