module Idv
  module Steps
    module InheritedProofing
      class AgreementStep < VerifyBaseStep
        STEP_INDICATOR_STEP = :getting_started

        def call
          # binding.pry
          doc_capture_session = create_document_capture_session(document_capture_session_uuid_key)
          InheritedProofingJob.perform_now(flow_session, result_id: doc_capture_session.result_id)
          # enqueue_job
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
