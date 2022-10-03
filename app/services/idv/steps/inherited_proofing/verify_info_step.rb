module Idv
  module Steps
    module InheritedProofing
      class VerifyInfoStep < InheritedProofingBaseStep
        STEP_INDICATOR_STEP = :verify_info
        def call
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
      end
    end
  end
end
