module Idv
  module VerifyInfoConcern
    extend ActiveSupport::Concern

    STEP_NAME = 'verify_info'.freeze

    def shared_update
      return if idv_session.verify_info_step_document_capture_session_uuid
      analytics.idv_doc_auth_verify_submitted(**analytics_arguments)
      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('verify', :update, true)

      set_state_id_type

      ssn_rate_limiter.increment!

      document_capture_session = DocumentCaptureSession.create(
        user_id: current_user.id,
        issuer: sp_session[:issuer],
      )
      document_capture_session.requested_at = Time.zone.now

      idv_session.verify_info_step_document_capture_session_uuid = document_capture_session.uuid
      idv_session.vendor_phone_confirmation = false
      idv_session.user_phone_confirmation = false

      pii[:uuid_prefix] = ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id
      pii[:ssn] = idv_session.ssn
      Idv::Agent.new(pii).proof_resolution(
        document_capture_session,
        should_proof_state_id: should_use_aamva?(pii),
        trace_id: amzn_trace_id,
        user_id: current_user.id,
        threatmetrix_session_id: idv_session.threatmetrix_session_id,
        request_ip: request.remote_ip,
        double_address_verification: capture_secondary_id_enabled,
      )

      return true
    end

    private

    def capture_secondary_id_enabled
      current_user.establishing_in_person_enrollment&.
          capture_secondary_id_enabled || false
    end

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

    def resolution_rate_limiter
      @resolution_rate_limiter ||= RateLimiter.new(
        user: current_user,
        rate_limit_type: :idv_resolution,
      )
    end

    def ssn_rate_limiter
      @ssn_rate_limiter ||= RateLimiter.new(
        target: Pii::Fingerprinter.fingerprint(idv_session.ssn),
        rate_limit_type: :proof_ssn,
      )
    end

    def idv_failure(result)
      proofing_results_exception = result.extra.dig(:proofing_results, :exception)
      is_mva_exception = result.extra.dig(
        :proofing_results,
        :context,
        :stages,
        :state_id,
        :mva_exception,
      )

      resolution_rate_limiter.increment! if proofing_results_exception.blank?

      if ssn_rate_limiter.limited?
        idv_failure_log_rate_limited(:proof_ssn)
        redirect_to idv_session_errors_ssn_failure_url
      elsif resolution_rate_limiter.limited?
        idv_failure_log_rate_limited(:idv_resolution)
        redirect_to rate_limited_url
      elsif proofing_results_exception.present? && is_mva_exception
        idv_failure_log_warning
        redirect_to state_id_warning_url
      elsif proofing_results_exception.present?
        idv_failure_log_error
        redirect_to exception_url
      else
        idv_failure_log_warning
        redirect_to warning_url
      end
    end

    def idv_failure_log_rate_limited(rate_limit_type)
      if rate_limit_type == :proof_ssn
        irs_attempts_api_tracker.idv_verification_rate_limited(limiter_context: 'multi-session')
        analytics.rate_limit_reached(
          limiter_type: :proof_ssn,
          step_name: STEP_NAME,
        )
      elsif rate_limit_type == :idv_resolution
        irs_attempts_api_tracker.idv_verification_rate_limited(limiter_context: 'single-session')
        analytics.rate_limit_reached(
          limiter_type: :idv_resolution,
          step_name: STEP_NAME,
        )
      end
    end

    def idv_failure_log_error
      analytics.idv_doc_auth_exception_visited(
        step_name: STEP_NAME,
        remaining_attempts: resolution_rate_limiter.remaining_count,
      )
    end

    def idv_failure_log_warning
      analytics.idv_doc_auth_warning_visited(
        step_name: STEP_NAME,
        remaining_attempts: resolution_rate_limiter.remaining_count,
      )
    end

    def rate_limited_url
      idv_session_errors_failure_url
    end

    def exception_url
      idv_session_errors_exception_url(flow: flow_param)
    end

    def state_id_warning_url
      idv_session_errors_state_id_warning_url(flow: flow_param)
    end

    def warning_url
      idv_session_errors_warning_url(flow: flow_param)
    end

    def process_async_state(current_async_state)
      if current_async_state.done?
        async_state_done(current_async_state)
        return
      end

      if current_async_state.in_progress?
        render 'shared/wait'
        return
      end

      return if confirm_not_rate_limited

      if current_async_state.none?
        idv_session.invalidate_verify_info_step!
        render :show
      elsif current_async_state.missing?
        analytics.idv_proofing_resolution_result_missing
        flash.now[:error] = I18n.t('idv.failure.timeout')
        render :show

        delete_async
        idv_session.invalidate_verify_info_step!

        log_idv_verification_submitted_event(
          success: false,
          failure_reason: { idv_verification: [:timeout] },
        )
      end
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
          address_edited: !!idv_session.address_edited,
          address_line2_present: !pii[:address2].blank?,
          pii_like_keypaths: [[:errors, :ssn], [:response_body, :first_name],
                              [:same_address_as_id],
                              [:state_id, :state_id_jurisdiction]],
        },
      )
      log_idv_verification_submitted_event(
        success: form_response.success?,
        failure_reason: irs_attempts_api_tracker.parse_failure_reason(form_response),
      )

      form_response = form_response.merge(check_ssn) if form_response.success?
      summarize_result_and_rate_limit_failures(form_response)
      delete_async

      if form_response.success?
        save_threatmetrix_status(form_response)
        move_applicant_to_idv_session
        idv_session.mark_verify_info_step_complete!
        idv_session.invalidate_steps_after_verify_info!

        flash[:success] = t('doc_auth.forms.doc_success')
        redirect_to next_step_url
      else
        idv_session.invalidate_verify_info_step!
      end

      analytics.idv_doc_auth_verify_proofing_results(**analytics_arguments, **form_response.to_h)
    end

    def next_step_url
      return idv_request_letter_url if FeatureManagement.idv_by_mail_only?
      idv_phone_url
    end

    def save_threatmetrix_status(form_response)
      review_status = form_response.extra.dig(:proofing_results, :threatmetrix_review_status)
      idv_session.threatmetrix_review_status = review_status
    end

    def summarize_result_and_rate_limit_failures(summary_result)
      if summary_result.success?
        add_proofing_components
        ssn_rate_limiter.reset!
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
        ssn: idv_session.ssn,
        failure_reason: failure_reason,
      )
    end

    def check_ssn
      Idv::SsnForm.new(current_user).submit(ssn: idv_session.ssn)
    end

    def move_applicant_to_idv_session
      idv_session.applicant = pii
      idv_session.applicant[:ssn] = idv_session.ssn
      idv_session.applicant['uuid'] = current_user.uuid
      delete_pii
    end

    def delete_pii
      idv_session.pii_from_doc = nil
      if defined?(flow_session) # no longer defined for remote flow
        flow_session.delete(:pii_from_user)
      end
    end

    def add_proofing_costs(results)
      results[:context][:stages].each do |stage, hash|
        if stage == :resolution
          # transaction_id comes from ConversationId
          add_cost(:lexis_nexis_resolution, transaction_id: hash[:transaction_id])
        elsif stage == :state_id
          next if hash[:exception].present?
          add_cost(:aamva, transaction_id: hash[:transaction_id])
          track_aamva unless hash[:vendor_name] == 'UnsupportedJurisdiction'
        elsif stage == :threatmetrix
          # transaction_id comes from request_id
          tmx_id = hash[:transaction_id]
          log_irs_tmx_fraud_check_event(hash, current_user) if tmx_id
          add_cost(:threatmetrix, transaction_id: tmx_id) if tmx_id
        end
      end
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
