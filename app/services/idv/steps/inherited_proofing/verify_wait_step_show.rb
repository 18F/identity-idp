module Idv
  module Steps
    module InheritedProofing
      class VerifyWaitStepShow < VerifyBaseStep
        include UserPiiJobInitiator
        include UserPiiManagable
        include Idv::InheritedProofing::ServiceProviderForms
        delegate :controller, :idv_session, to: :@flow

        STEP_INDICATOR_STEP = :getting_started

        def self.analytics_optional_step_event
          :idv_doc_auth_optional_verify_wait_submitted
        end

        def call
          poll_with_meta_refresh(IdentityConfig.store.poll_rate_for_verify_in_seconds)

          process_async_state(async_state)
        end

        private

        def process_async_state(current_async_state)
          return if current_async_state.in_progress?

          if current_async_state.none?
            mark_step_incomplete(:agreement)
          elsif current_async_state.missing?
            flash[:error] = I18n.t('idv.failure.timeout')
            delete_async
            mark_step_incomplete(:agreement)
            @flow.analytics.idv_proofing_resolution_result_missing
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

          delete_async

          if form_response.success?
            inherited_proofing_save_user_pii_to_session!(form.user_pii)
            mark_step_complete(:verify_wait)
          elsif throttle.throttled?
            idv_failure(form_response)
          else
            mark_step_complete(:agreement)
            idv_failure(form_response)
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

        # Base class overrides

        def throttle
          @throttle ||= Throttle.new(
            user: current_user,
            throttle_type: :inherited_proofing,
          )
        end

        def idv_failure_log_throttled
          @flow.analytics.throttler_rate_limit_triggered(
            throttle_type: throttle.throttle_type,
            step_name: self.class.name,
          )
        end

        def throttled_url
          idv_inherited_proofing_errors_failure_url(flow: :inherited_proofing)
        end

        def exception_url
          idv_inherited_proofing_errors_failure_url(flow: :inherited_proofing)
        end

        def warning_url
          idv_inherited_proofing_errors_no_information_url(flow: :inherited_proofing)
        end
      end
    end
  end
end
