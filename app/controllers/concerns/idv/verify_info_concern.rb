# frozen_string_literal: true

module Idv
  module VerifyInfoConcern
    extend ActiveSupport::Concern

    STEP_NAME = 'verify_info'

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

      # proof_resolution job expects these values
      agent_pii = pii.merge(
        uuid: current_user.uuid,
        uuid_prefix: ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id,
        ssn: idv_session.ssn,
      )
      Idv::Agent.new(agent_pii).proof_resolution(
        document_capture_session,
        should_proof_state_id: aamva_state?,
        trace_id: amzn_trace_id,
        user_id: current_user.id,
        threatmetrix_session_id: idv_session.threatmetrix_session_id,
        request_ip: request.remote_ip,
        ipp_enrollment_in_progress: ipp_enrollment_in_progress?,
      )

      return true
    end

    private

    def ipp_enrollment_in_progress?
      current_user.has_in_person_enrollment?
    end

    def aamva_state?
      IdentityConfig.store.aamva_supported_jurisdictions.include?(pii['state_id_jurisdiction'])
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
        remaining_submit_attempts: resolution_rate_limiter.remaining_count,
      )
    end

    def idv_failure_log_warning
      analytics.idv_doc_auth_warning_visited(
        step_name: STEP_NAME,
        remaining_submit_attempts: resolution_rate_limiter.remaining_count,
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

      return if confirm_not_rate_limited_after_doc_auth

      if current_async_state.none?
        render :show
      elsif current_async_state.missing?
        analytics.idv_proofing_resolution_result_missing
        flash.now[:error] = I18n.t('idv.failure.timeout')
        render :show

        delete_async

        log_idv_verification_submitted_event(
          success: false,
        )
      end
    end

    def async_state_done(current_async_state)
      add_proofing_costs(current_async_state.result)

      create_fraud_review_request_if_needed(current_async_state.result)

      track_attempts_api_fraud_check_event_if_needed(current_async_state.result)

      form_response = idv_result_to_form_response(
        result: current_async_state.result,
        state: pii[:state],
        state_id_jurisdiction: pii[:state_id_jurisdiction],
        state_id_number: pii[:state_id_number],
        # todo: add other edited fields?
        extra: {
          address_edited: !!idv_session.address_edited,
          address_line2_present: !pii[:address2].blank?,
          pii_like_keypaths: [
            [:errors, :ssn],
            [:proofing_results, :context, :stages, :resolution, :errors, :ssn],
            [:proofing_results, :context, :stages, :residential_address, :errors, :ssn],
            [:proofing_results, :context, :stages, :threatmetrix, :response_body, :first_name],
            [:same_address_as_id],
            [:proofing_results, :context, :stages, :state_id, :state_id_jurisdiction],
          ],
        },
      )
      log_idv_verification_submitted_event(
        success: form_response.success?,
      )

      form_response.extra[:ssn_is_unique] = DuplicateSsnFinder.new(
        ssn: idv_session.ssn,
        user: current_user,
      ).ssn_is_unique?

      summarize_result_and_rate_limit(form_response)
      delete_async

      if form_response.success?
        save_threatmetrix_status(form_response)
        move_applicant_to_idv_session
        idv_session.mark_verify_info_step_complete!

        flash[:success] = t('doc_auth.forms.doc_success')
        redirect_to next_step_url
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

    def summarize_result_and_rate_limit(summary_result)
      proofing_results_exception = summary_result.extra.dig(:proofing_results, :exception)
      resolution_rate_limiter.increment! if proofing_results_exception.blank?

      if summary_result.success?
        add_proofing_components
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

    def log_idv_verification_submitted_event(success: false)
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
      )
    end

    def create_fraud_review_request_if_needed(result)
      return unless FeatureManagement.proofing_device_profiling_collecting_enabled?

      threatmetrix_result = result.dig(:context, :stages, :threatmetrix)
      return unless threatmetrix_result

      return if threatmetrix_result[:review_status] == 'pass'

      FraudReviewRequest.create(
        user: current_user,
        login_session_id: Digest::SHA1.hexdigest(current_user.unique_session_id.to_s),
      )
    end

    def track_attempts_api_fraud_check_event_if_needed(result)
      return unless FeatureManagement.proofing_device_profiling_collecting_enabled?

      threatmetrix_result = result.dig(:context, :stages, :threatmetrix)
      return unless threatmetrix_result

      success = threatmetrix_result[:review_status] == 'pass'

      irs_attempts_api_tracker.idv_tmx_fraud_check(
        success: success,
      )
    end

    def move_applicant_to_idv_session
      idv_session.applicant = pii
      idv_session.applicant[:ssn] = idv_session.ssn
      idv_session.applicant['uuid'] = current_user.uuid
    end

    def add_proofing_costs(results)
      results[:context][:stages].each do |stage, hash|
        if stage == :resolution
          # transaction_id comes from ConversationId
          add_cost(:lexis_nexis_resolution, transaction_id: hash[:transaction_id])
        elsif stage == :residential_address
          next if pii[:same_address_as_id] == 'true'
          next if hash[:vendor_name] == 'ResidentialAddressNotRequired'
          add_cost(:lexis_nexis_resolution, transaction_id: hash[:transaction_id])
        elsif stage == :state_id
          next if hash[:exception].present?
          next if hash[:vendor_name] == 'UnsupportedJurisdiction'
          # transaction_id comes from TransactionLocatorId
          add_cost(:aamva, transaction_id: hash[:transaction_id])
          track_aamva
        elsif stage == :threatmetrix
          # transaction_id comes from request_id
          if hash[:transaction_id]
            add_cost(
              :threatmetrix,
              transaction_id: hash[:transaction_id],
            )
          end
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
      Db::SpCost::AddSpCost.call(current_sp, token, transaction_id: transaction_id)
    end
  end
end
