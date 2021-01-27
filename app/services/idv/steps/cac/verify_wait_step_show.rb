module Idv
  module Steps
    module Cac
      class VerifyWaitStepShow < VerifyBaseStep
        class TimeoutError < StandardError; end

        def call
          poll_with_meta_refresh(AppConfig.env.poll_rate_for_verify_in_seconds.to_i)

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
            NewRelic::Agent.notice_error(TimeoutError.new)
            mark_step_incomplete(:verify)
          elsif current_async_state.done?
            async_state_done(current_async_state)
          end
        end

        def async_state_done(current_async_state)
          add_cost(:lexis_nexis_resolution)
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
          dcs_uuid = flow_session[cac_verify_document_capture_session_uuid_key]
          dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
          return ProofingSessionAsyncResult.none if dcs_uuid.nil?
          return ProofingSessionAsyncResult.timed_out if dcs.nil?

          proofing_job_result = dcs.load_proofing_result
          return ProofingSessionAsyncResult.timed_out if proofing_job_result.nil?

          proofing_job_result
        end

        def summarize_result_and_throttle_failures(summary_result)
          summary_result.success? ? summary_result : idv_failure(summary_result)
        end

        def check_ssn(pii_from_doc)
          result = Idv::SsnForm.new(current_user).submit(ssn: pii_from_doc[:ssn])
          save_legacy_state(pii_from_doc) if result.success?
          result
        end

        def save_legacy_state(pii_from_doc)
          skip_legacy_steps
          idv_session['params'] = pii_from_doc
          idv_session['applicant'] = pii_from_doc
          idv_session['applicant']['uuid'] = current_user.uuid
        end

        def skip_legacy_steps
          idv_session['profile_confirmation'] = true
          idv_session['vendor_phone_confirmation'] = false
          idv_session['user_phone_confirmation'] = false
          idv_session['address_verification_mechanism'] = 'phone'
          idv_session['resolution_successful'] = 'phone'
        end

        def delete_async
          flow_session.delete(cac_verify_document_capture_session_uuid_key)
        end
      end
    end
  end
end
