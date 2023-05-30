module Idv
  module StepIndicatorConcern
    extend ActiveSupport::Concern

    included do
      helper_method :step_indicator_steps
    end

    def step_indicator_steps
      if in_person_proofing?
        if gpo_address_verification?
          Idv::Flows::InPersonFlow::STEP_INDICATOR_STEPS_GPO
        else
          Idv::Flows::InPersonFlow::STEP_INDICATOR_STEPS
        end
      elsif gpo_address_verification?
        Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS_GPO
      else
        Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS
      end
    end

    private

    def in_person_proofing?
      proofing_components_as_hash['document_check'] == Idp::Constants::Vendors::USPS
    end

    def gpo_address_verification?
      # Proofing component values are (currently) never reset between proofing attempts, hence why
      # this refers to the session address verification mechanism and not the proofing component.
      return true if current_user&.gpo_verification_pending_profile?

      return idv_session&.address_verification_mechanism == 'gpo' if defined?(idv_session)
    end

    def proofing_components
      return {} if !current_user

      if current_user.pending_profile
        current_user.pending_profile.proofing_components
      else
        ProofingComponent.find_by(user: current_user).as_json
      end
    end

    def proofing_components_as_hash
      # A proofing component record exists as a zero-or-one-to-one relation with a user, and values
      # are set during identity verification. These values are recorded to the profile at creation,
      # including for a pending profile.
      @proofing_components_as_hash ||= proofing_components.to_h
    end
  end
end
