module Idv
  module Steps
    module InPerson
      class VerifyStep < VerifyBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def self.analytics_visited_event
          :idv_doc_auth_verify_visited
        end

        def self.analytics_submitted_event
          :idv_doc_auth_verify_submitted
        end

        def call
          pii[:state_id_type] = 'drivers_license' unless invalid_state?
          add_proofing_component
          enqueue_job
        end

        def extra_view_variables
          {
            capture_secondary_id_enabled: capture_secondary_id_enabled,
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

        def capture_secondary_id_enabled
          current_user.establishing_in_person_enrollment.capture_secondary_id_enabled
        end

        def pii
          flow_session[:pii_from_user]
        end
      end
    end
  end
end
