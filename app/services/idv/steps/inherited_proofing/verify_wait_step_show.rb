module Idv
  module Steps
    module InheritedProofing
      class VerifyWaitStepShow < VerifyBaseStep
        include UserPiiManagable
        include Idv::InheritedProofing::ServiceProviderForms
        delegate :controller, :idv_session, to: :@flow

        STEP_INDICATOR_STEP = :getting_started

        def self.analytics_optional_step_event
          :idv_inherited_proofing_optional_verify_wait_submitted
        end

        def call
          poll_with_meta_refresh(IdentityConfig.store.poll_rate_for_verify_in_seconds)

          process_async_state(async_state)
        end

        private

        def process_async_state(current_async_state)
          if current_async_state.none?
            mark_step_incomplete(:agreement)
          elsif current_async_state.in_progress?
            nil
          elsif current_async_state.missing?
            flash[:error] = I18n.t('idv.failure.timeout')
            # Need to add path to error pages once they exist
            # LG-7257
            # This method overrides VerifyBaseStep#process_async_state:
            # See the VerifyBaseStep#process_async_state "elsif current_async_state.missing?"
            # logic as to what is typically needed/performed when hitting this logic path.
          elsif current_async_state.done?
            async_state_done(current_async_state)
          end
        end

        def async_state
          return ProofingSessionAsyncResult.none if dcs_uuid.nil?
          return ProofingSessionAsyncResult.missing if document_capture_session.nil?
          return ProofingSessionAsyncResult.missing if api_job_result.nil?

          api_job_result
        end

        def async_state_done(_current_async_state)
          service_provider = controller.inherited_proofing_service_provider

          form = inherited_proofing_form_for(
            service_provider,
            payload_hash: api_job_result[:result],
          )
          form_response = form.submit

          if form_response.success?
            inherited_proofing_save_user_pii_to_session!(form.user_pii)
            mark_step_complete(:verify_wait)
          else
            mark_step_incomplete(:agreement)
          end

          form_response
        end

        def dcs_uuid
          @dcs_uuid ||=
            flow_session[inherited_proofing_verify_step_document_capture_session_uuid_key]
        end

        def document_capture_session
          @document_capture_session ||= DocumentCaptureSession.find_by(uuid: dcs_uuid)
        end

        def api_job_result
          document_capture_session.load_proofing_result
        end
      end
    end
  end
end
