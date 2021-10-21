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
        form_response = idv_result_to_form_response(
          idv_result: current_async_state.result,
          state: flow_session[:pii_from_doc][:state],
          extra: {
            address_edited: !!flow_session['address_edited'],
            pii_like_keypaths: [[:errors, :ssn]],
          },
        )

        if form_response.success?
          response = check_ssn(flow_session[:pii_from_doc]) if form_response.success?
          form_response = form_response.merge(response)
        end
        summarize_result_and_throttle_failures(form_response)
        delete_async

        if form_response.success?
          mark_step_complete(:verify_wait)
        else
          mark_step_incomplete(:verify)
        end

        form_response
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
