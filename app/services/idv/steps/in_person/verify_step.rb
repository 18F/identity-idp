module Idv
  module Steps
    module InPerson
      class VerifyStep < VerifyBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          pii[:state_id_type] = 'drivers_license' unless invalid_state?
          add_proofing_component
          enqueue_job
        end

        def extra_view_variables
          {
            pii: pii,
            step_url: method(:idv_in_person_step_url),
          }
        end

        private

        def add_proofing_component
          ProofingComponent.
            create_or_find_by(user: current_user).
            update(document_check: Idp::Constants::Vendors::USPS)
        end

        def pii
          flow_session[:pii_from_user]
        end
      end
    end
  end
end
