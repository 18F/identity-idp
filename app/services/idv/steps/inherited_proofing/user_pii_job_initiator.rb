module Idv
  module Steps
    module InheritedProofing
      module UserPiiJobInitiator
        private

        def enqueue_job
          return if api_call_already_in_progress?

          create_document_capture_session(
            inherited_proofing_verify_step_document_capture_session_uuid_key,
          ).tap do |doc_capture_session|
            doc_capture_session.create_proofing_session

            InheritedProofingJob.perform_later(
              controller.inherited_proofing_service_provider,
              controller.inherited_proofing_service_provider_data,
              doc_capture_session.uuid,
            )
          end
        end

        def api_call_already_in_progress?
          DocumentCaptureSession.find_by(
            uuid: flow_session[inherited_proofing_verify_step_document_capture_session_uuid_key],
          ).present?
        end

        def delete_async
          flow_session.delete(inherited_proofing_verify_step_document_capture_session_uuid_key)
        end
      end
    end
  end
end
