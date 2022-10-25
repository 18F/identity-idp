module Idv
  module Steps
    module InheritedProofing
      class AgreementStep < VerifyBaseStep
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

        def enqueue_job
          return if api_call_already_in_progress?

          doc_capture_session = create_document_capture_session(
            inherited_proofing_verify_step_document_capture_session_uuid_key,
          )

          doc_capture_session.create_doc_auth_session

          InheritedProofingJob.perform_later(
            controller.inherited_proofing_service_provider,
            controller.inherited_proofing_service_provider_data,
            doc_capture_session.uuid,
          )
        end

        def api_call_already_in_progress?
          DocumentCaptureSession.find_by(
            uuid: flow_session['inherited_proofing_verify_step_document_capture_session_uuid'],
          )&.in_progress?
        end
      end
    end
  end
end
