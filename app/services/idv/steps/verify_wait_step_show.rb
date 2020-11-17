module Idv
  module Steps
    class VerifyWaitStepShow < VerifyBaseStep
      def call
        poll_with_meta_refresh(AppConfig.env.poll_rate_for_verify_in_seconds.to_i)

        process_async_state(async_state)
      end

      private

      def process_async_state(current_async_state)
        case current_async_state.status
        when :none
          mark_step_incomplete(:verify)
        when :in_progress
          nil
        when :timed_out
          flash[:info] = I18n.t('idv.failure.timeout')
          delete_async
          mark_step_incomplete(:verify)
        when :done
          async_state_done(current_async_state)
        end
      end

      def async_state_done(current_async_state)
        add_proofing_costs(current_async_state.result)
        response = idv_result_to_form_response(current_async_state.result)
        response = check_ssn(current_async_state.pii) if response.success?
        summarize_result_and_throttle_failures(response)
        delete_async

        if response.success?
          flash[:success] = I18n.t('doc_auth.forms.doc_success')
          mark_step_complete(:verify_wait)
        else
          mark_step_incomplete(:verify)
        end

        response
      end

      def async_state
        dcs_uuid = flow_session[verify_step_document_capture_session_uuid_key]
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
        flow_session.delete(verify_step_document_capture_session_uuid_key)
      end
    end
  end
end
