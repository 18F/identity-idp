module Idv
  module VerifyInfoConcern
    extend ActiveSupport::Concern

    def resolution_throttle
      @resolution_throttle ||= Throttle.new(
        user: current_user,
        throttle_type: :idv_resolution,
      )
    end

    def ssn_throttle
      @ssn_throttle ||= Throttle.new(
        target: Pii::Fingerprinter.fingerprint(pii[:ssn]),
        throttle_type: :proof_ssn,
      )
    end

    def idv_failure(result)
      proofing_results_exception = result.extra.dig(:proofing_results, :exception)

      resolution_throttle.increment! if proofing_results_exception.blank?
      if resolution_throttle.throttled?
        idv_failure_log_throttled(:idv_resolution)
        redirect_to throttled_url
      elsif proofing_results_exception.present?
        idv_failure_log_error
        redirect_to exception_url
      else
        idv_failure_log_warning
        redirect_to warning_url
      end
    end

    def idv_failure_log_throttled(throttle_type)
      if throttle_type == :idv_resolution
        irs_attempts_api_tracker.idv_verification_rate_limited(throttle_context: 'single-session')
        analytics.throttler_rate_limit_triggered(
          throttle_type: :idv_resolution,
          step_name: self.class.name,
        )
      elsif throttle_type == :proof_ssn
        irs_attempts_api_tracker.idv_verification_rate_limited(throttle_context: 'multi-session')
      end
    end

    def idv_failure_log_error
      analytics.idv_doc_auth_exception_visited(
        step_name: self.class.name,
        remaining_attempts: resolution_throttle.remaining_count,
      )
    end

    def idv_failure_log_warning
      analytics.idv_doc_auth_warning_visited(
        step_name: self.class.name,
        remaining_attempts: resolution_throttle.remaining_count,
      )
    end

    def throttled_url
      idv_session_errors_failure_url
    end

    def exception_url
      idv_session_errors_exception_url
    end

    def warning_url
      idv_session_errors_warning_url
    end

    def async_state_done(current_async_state)
      add_proofing_costs(current_async_state.result)
      form_response = idv_result_to_form_response(
        result: current_async_state.result,
        state: pii[:state],
        state_id_jurisdiction: pii[:state_id_jurisdiction],
        state_id_number: pii[:state_id_number],
        # todo: add other edited fields?
        extra: {
          address_edited: !!flow_session['address_edited'],
          pii_like_keypaths: [[:errors, :ssn], [:response_body, :first_name]],
        },
      )
      log_idv_verification_submitted_event(
        success: form_response.success?,
        failure_reason: irs_attempts_api_tracker.parse_failure_reason(form_response),
      )

      if form_response.success?
        response = check_ssn
        form_response = form_response.merge(response)
      end
      summarize_result_and_throttle_failures(form_response)
      delete_async

      if form_response.success?
        idv_session.resolution_successful = true
        redirect_to next_url
      else
        idv_session.resolution_successful = false
      end

      analytics.idv_doc_auth_verify_proofing_results(**form_response.to_h)
    end

    def summarize_result_and_throttle_failures(summary_result)
      if summary_result.success?
        add_proofing_components
        summary_result
      else
        idv_failure(summary_result)
      end
    end

    def add_proofing_components
      ProofingComponent.create_or_find_by(user: current_user).update(
        resolution_check: Idp::Constants::Vendors::LEXIS_NEXIS,
        source_check: Idp::Constants::Vendors::AAMVA,
      )
    end

    def load_async_state
      dcs_uuid = idv_session.verify_info_step_document_capture_session_uuid
      dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
      return ProofingSessionAsyncResult.none if dcs_uuid.nil?
      return ProofingSessionAsyncResult.missing if dcs.nil?

      proofing_job_result = dcs.load_proofing_result
      return ProofingSessionAsyncResult.missing if proofing_job_result.nil?

      proofing_job_result
    end

    def delete_async
      idv_session.verify_info_step_document_capture_session_uuid = nil
    end

    def idv_result_to_form_response(
      result:,
      state: nil,
      state_id_jurisdiction: nil,
      state_id_number: nil,
      extra: {}
    )
      state_id = result.dig(:context, :stages, :state_id)
      if state_id
        state_id[:state] = state if state
        state_id[:state_id_jurisdiction] = state_id_jurisdiction if state_id_jurisdiction
        if state_id_number
          state_id[:state_id_number] =
            StringRedacter.redact_alphanumeric(state_id_number)
        end
      end

      FormResponse.new(
        success: result[:success],
        errors: result[:errors],
        extra: extra.merge(proofing_results: result.except(:errors, :success)),
      )
    end

    def log_idv_verification_submitted_event(success: false, failure_reason: nil)
      pii_from_doc = pii || {}
      irs_attempts_api_tracker.idv_verification_submitted(
        success: success,
        document_state: pii_from_doc[:state],
        document_number: pii_from_doc[:state_id_number],
        document_issued: pii_from_doc[:state_id_issued],
        document_expiration: pii_from_doc[:state_id_expiration],
        first_name: pii_from_doc[:first_name],
        last_name: pii_from_doc[:last_name],
        date_of_birth: pii_from_doc[:dob],
        address: pii_from_doc[:address1],
        ssn: pii_from_doc[:ssn],
        failure_reason: failure_reason,
      )
    end

    def check_ssn
      result = Idv::SsnForm.new(current_user).submit(ssn: pii[:ssn])

      if result.success?
        save_legacy_state
        delete_pii
      end

      result
    end

    def save_legacy_state
      skip_legacy_steps
      idv_session.applicant = pii
      idv_session.applicant['uuid'] = current_user.uuid
    end

    def skip_legacy_steps
      idv_session.profile_confirmation = true
      idv_session.vendor_phone_confirmation = false
      idv_session.user_phone_confirmation = false
      idv_session.address_verification_mechanism = 'phone'
      idv_session.resolution_successful = 'phone'
    end
  end
end
