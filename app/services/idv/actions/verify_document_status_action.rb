module Idv
  module Actions
    class VerifyDocumentStatusAction < Idv::Steps::VerifyBaseStep
      def call
        process_async_state(async_state)
      end

      private

      def process_async_state(current_async_state)
        form = ApiDocumentVerificationStatusForm.new(
          async_state: current_async_state,
          document_capture_session: document_capture_session,
        )

        form_response = form.submit

        if current_async_state.status == :done
          process_result(current_async_state.result)
          async_state_done if form_response.success?
        end

        presenter = ImageUploadResponsePresenter.new(
          form: form,
          form_response: form_response,
        )

        status = :accepted if current_async_state.status == :in_progress

        render_json(
          presenter,
          status: status || presenter.status,
        )
      end

      def async_state_done
        delete_async
        mark_step_complete(:document_capture)
        save_proofing_components
      end

      def process_result(result)
        add_cost(:acuant_result) if result.to_h[:billed]
      end

      def document_capture_session
        dcs_uuid = flow_session[verify_document_capture_session_uuid_key]
        @document_capture_session ||= DocumentCaptureSession.find_by(uuid: dcs_uuid)
      end

      def async_state
        return ProofingDocumentCaptureSessionResult.timed_out if document_capture_session.nil?

        proofing_job_result = document_capture_session.load_proofing_result
        return ProofingDocumentCaptureSessionResult.timed_out if proofing_job_result.nil?

        if proofing_job_result.result
          proofing_job_result.done
        elsif proofing_job_result.pii
          ProofingDocumentCaptureSessionResult.in_progress
        end
      end

      def delete_async
        flow_session.delete(verify_document_capture_session_uuid_key)
      end
    end
  end
end
