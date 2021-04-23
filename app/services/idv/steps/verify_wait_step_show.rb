module Idv
  module Steps
    class VerifyWaitStepShow < VerifyBaseStep
      STEP_INDICATOR_STEP = :verify_info

      def call
        poll_with_meta_refresh(IdentityConfig.store.poll_rate_for_verify_in_seconds)

        process_async_state(async_state)
      end

      private

      def process_async_state(current_async_state)
        if current_async_state.none?
          mark_step_incomplete(:verify)
        elsif current_async_state.in_progress?
          nil
        elsif current_async_state.timed_out?
          flash[:error] = I18n.t('idv.failure.timeout')
          delete_async
          mark_step_incomplete(:verify)
          @flow.analytics.track_event(Analytics::PROOFING_RESOLUTION_TIMEOUT)
        elsif current_async_state.done?
          async_state_done(current_async_state)
        end
      end

      def async_state_done(current_async_state)
        add_proofing_costs(current_async_state.result)
        response = idv_result_to_form_response(current_async_state.result)
        response = check_ssn(flow_session[:pii_from_doc]) if response.success?
        summarize_result_and_throttle_failures(response)
        delete_async

        if response.success?
          mark_step_complete(:verify_wait)
        else
          mark_step_incomplete(:verify)
        end

        response
      end

      def async_state
        dcs_uuid = flow_session[verify_step_document_capture_session_uuid_key]
        dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
        return ProofingSessionAsyncResult.none if dcs_uuid.nil?
        return ProofingSessionAsyncResult.timed_out if dcs.nil?

        proofing_job_result = dcs.load_proofing_result
        return ProofingSessionAsyncResult.timed_out if proofing_job_result.nil?

        proofing_job_result
      end

      def delete_async
        flow_session.delete(verify_step_document_capture_session_uuid_key)
      end
    end
  end
end
