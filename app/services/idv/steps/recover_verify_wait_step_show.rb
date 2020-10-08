module Idv
  module Steps
    class RecoverVerifyWaitStepShow < VerifyBaseStep
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
        add_proofing_costs(current_async_state.result)
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
        dcs_uuid = flow_session[:idv_recover_verify_step_document_capture_session_uuid]
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
        flow_session.delete(:idv_recover_verify_step_document_capture_session_uuid)
      end

      def idv_failure(result)
        attempter_increment if result.extra.dig(:proofing_results, :exception).blank?
        if attempter_throttled?
          redirect_to idv_session_errors_recovery_failure_url
        elsif result.extra.dig(:proofing_results, :exception).present?
          redirect_to idv_session_errors_recovery_exception_url
        else
          redirect_to idv_session_errors_recovery_warning_url
        end
        result
      end

      def summarize_result_and_throttle_failures(summary_result)
        if summary_result.success? && doc_auth_pii_matches_decrypted_pii
          add_proofing_components
          summary_result
        else
          idv_failure(summary_result)
        end
      end

      def doc_auth_pii_matches_decrypted_pii
        pii_from_doc = session['idv/recovery']['pii_from_doc']
        decrypted_pii = JSON.parse(saved_pii)
        return unless pii_matches_data_on_file?(pii_from_doc, decrypted_pii)

        recovery_success
      end

      def recovery_success
        flash[:success] = I18n.t('recover.reverify.success')
        redirect_to account_url
        session['need_two_factor_authentication'] = false
        true
      end

      def saved_pii
        session['decrypted_pii']
      end

      def pii_matches_data_on_file?(pii_from_doc, decrypted_pii)
        %w[first_name last_name dob ssn].each do |key|
          return false unless pii_from_doc[key] == decrypted_pii[key]
        end
        true
      end
    end
  end
end
