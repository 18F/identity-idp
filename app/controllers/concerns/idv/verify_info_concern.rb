module Idv
  module VerifyInfoConcern
    extend ActiveSupport::Concern

    def should_use_aamva?(pii)
      aamva_state?(pii) && !aamva_disallowed_for_service_provider?
    end

    def aamva_state?(pii)
      IdentityConfig.store.aamva_supported_jurisdictions.include?(
        pii['state_id_jurisdiction'],
      )
    end

    def aamva_disallowed_for_service_provider?
      return false if sp_session.nil?
      banlist = IdentityConfig.store.aamva_sp_banlist_issuers
      banlist.include?(sp_session[:issuer])
    end

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
          address_line2_present: !pii[:address2].blank?,
          pii_like_keypaths: [[:errors, :ssn], [:response_body, :first_name]],
        },
      )
      log_idv_verification_submitted_event(
        success: form_response.success?,
        failure_reason: irs_attempts_api_tracker.parse_failure_reason(form_response),
      )

      if form_response.success?
        form_response = form_response.merge(check_ssn)
      end
      summarize_result_and_throttle_failures(form_response)
      delete_async

      if form_response.success?
        move_applicant_to_idv_session
        idv_session.mark_verify_info_step_complete!
        idv_session.invalidate_steps_after_verify_info!
        redirect_to idv_phone_url
      else
        idv_session.invalidate_verify_info_step!
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
      Idv::SsnForm.new(current_user).submit(ssn: pii[:ssn])
    end

    def move_applicant_to_idv_session
      idv_session.applicant = pii
      idv_session.applicant['uuid'] = current_user.uuid
      delete_pii
    end

    def add_proofing_costs(results)
      results[:context][:stages].each do |stage, hash|
        if stage == :resolution
          # transaction_id comes from ConversationId
          add_cost(:lexis_nexis_resolution, transaction_id: hash[:transaction_id])
        elsif stage == :state_id
          next if hash[:vendor_name] == 'UnsupportedJurisdiction'
          process_aamva(hash[:transaction_id])
        elsif stage == :threatmetrix
          # transaction_id comes from request_id
          tmx_id = hash[:transaction_id]
          log_irs_tmx_fraud_check_event(hash) if tmx_id
          add_cost(:threatmetrix, transaction_id: tmx_id) if tmx_id
        end
      end
    end

    def process_aamva(transaction_id)
      # transaction_id comes from TransactionLocatorId
      add_cost(:aamva, transaction_id: transaction_id)
      track_aamva
    end

    def track_aamva
      return unless IdentityConfig.store.state_tracking_enabled
      doc_auth_log = DocAuthLog.find_by(user_id: current_user.id)
      return unless doc_auth_log
      doc_auth_log.aamva = true
      doc_auth_log.save!
    end

    def add_cost(token, transaction_id: nil)
      Db::SpCost::AddSpCost.call(current_sp, 2, token, transaction_id: transaction_id)
    end
  end
end
