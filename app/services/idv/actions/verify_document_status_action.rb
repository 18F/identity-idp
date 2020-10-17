module Idv
  module Actions
    class VerifyDocumentStatusAction < Idv::Steps::VerifyBaseStep
      def call
        process_async_state(async_state)
      end

      private

      def process_async_state(current_async_state)
        render_json case current_async_state.status
        when :none
          { success: true, status: nil }
        when :in_progress
          { success: true, status: 'in_progress' }
        when :timed_out
          { success: false, status: nil, errors: ['timeout'] }
        when :done
          status = async_state_done(current_async_state)
          { success: true, status: status ? 'success' : 'fail' }
        end
      end

      def async_state_done(current_async_state)
        result = current_async_state.result
        return false unless process_result(result)

        delete_async
        mark_step_complete(:document_capture)
        save_proofing_components
        # extract_pii_from_doc(result)
        true
      end

      def process_result(result)
        add_cost(:acuant_result) if result.to_h[:billed]
        response = idv_result_to_form_response(result)
        response.success?
      end

      def async_state
        dcs_uuid = flow_session[verify_document_capture_session_uuid_key]
        dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
        return ProofingDocumentCaptureSessionResult.none if dcs_uuid.nil?
        return ProofingDocumentCaptureSessionResult.timed_out if dcs.nil?

        proofing_job_result = dcs.load_proofing_result
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
