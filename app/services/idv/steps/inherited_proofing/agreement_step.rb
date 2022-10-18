module Idv
  module Steps
    module InheritedProofing
      class AgreementStep < VerifyBaseStep
        delegate :controller, :idv_session, to: :@flow
        STEP_INDICATOR_STEP = :getting_started

        def call
          enqueue_job
        end

        def form_submit
          Idv::ConsentForm.new.submit(consent_form_params)
        end

        def consent_form_params
          params.require(:inherited_proofing).permit(:ial2_consent_given)
        end

        def enqueue_job
          doc_capture_session = create_document_capture_session(
            inherited_proofing_verify_step_document_capture_session_uuid_key,
          )

          doc_capture_session.create_doc_auth_session

          InheritedProofingJob.perform_now(
            controller.inherited_proofing_service_provider_id,
            controller.inherited_proofing_service_provider_data, doc_capture_session.uuid
          )
        end
      end
    end
  end
end
