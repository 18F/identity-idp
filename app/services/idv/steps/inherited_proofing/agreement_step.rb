module Idv
  module Steps
    module InheritedProofing
      class AgreementStep < VerifyBaseStep
        include UserPiiJobInitiator

        delegate :controller, :idv_session, to: :@flow
        STEP_INDICATOR_STEP = :getting_started

        def self.analytics_visited_event
          :idv_inherited_proofing_agreement_visited
        end

        def self.analytics_submitted_event
          :idv_inherited_proofing_agreement_submitted
        end

        def call
          enqueue_job
        end

        def form_submit
          Idv::ConsentForm.new.submit(consent_form_params)
        end

        def consent_form_params
          params.require(:inherited_proofing).permit(:ial2_consent_given)
        end
      end
    end
  end
end
