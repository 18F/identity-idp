module Idv
  module Steps
    module InheritedProofing
      class VerifyInfoStep < InheritedProofingBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def self.analytics_visited_event
          :idv_doc_auth_verify_visited
        end

        def self.analytics_submitted_event
          :idv_doc_auth_verify_submitted
        end

        def call
          save_proofing_components
        end

        def extra_view_variables
          {
            pii: pii,
            step_url: method(:idv_inherited_proofing_step_url),
          }
        end

        def pii
          flow_session[:pii_from_user]
        end

        private

        def save_proofing_components
          raise 'current_user is not present' unless current_user.present?

          component_attributes = {
            inherited_proofing_proofed: true,
          }

          ProofingComponent.create_or_find_by(user: current_user).update(component_attributes)
        end
      end
    end
  end
end
