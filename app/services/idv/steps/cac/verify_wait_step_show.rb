module Idv
  module Steps
    module Cac
      class VerifyWaitStepShow < VerifyBaseStep
        def call
          poll_with_meta_refresh(Figaro.env.poll_rate_for_verify_in_seconds.to_i)

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
            mark_step_incomplete(:verify)
          when :done
            async_state_done(current_async_state)
          end
        end

        def async_state_done(current_async_state)
          response = idv_result_to_form_response(current_async_state.result)
          response = check_ssn(current_async_state.pii) if response.success?
          summarize_result_and_throttle_failures(response)

          if response.success?
            delete_async
            mark_step_complete(:verify_wait)
          else
            mark_step_incomplete(:verify)
          end
        end

        def async_state
          dcs_uuid = flow_session[cac_verify_document_capture_session_uuid_key]
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
