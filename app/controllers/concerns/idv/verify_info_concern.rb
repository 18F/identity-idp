# frozen_string_literal: true

module Idv
  # @attr idv_session [Idv::Session]
  module VerifyInfoConcern
    extend ActiveSupport::Concern

    STEP_NAME = 'verify_info'

    class_methods do
      def threatmetrix_session_id_present_or_not_required?(idv_session:)
        return true unless FeatureManagement.proofing_device_profiling_decisioning_enabled?
        idv_session.threatmetrix_session_id.present?
      end
    end

    def shared_update
      return if idv_session.verify_info_step_document_capture_session_uuid
      analytics.idv_doc_auth_verify_submitted(**analytics_arguments)
      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer])
        .call('verify', :update, true)

      ssn_rate_limiter.increment!

      document_capture_session = DocumentCaptureSession.create(
        user_id: current_user.id,
        issuer: sp_session[:issuer],
      )

      document_capture_session.requested_at = Time.zone.now

      idv_session.verify_info_step_document_capture_session_uuid = document_capture_session.uuid

      user_pii = pii
      user_pii[:best_effort_phone_number_for_socure] = best_effort_phone

      Idv::Agent.new(user_pii).proof_resolution(
        document_capture_session,
        trace_id: amzn_trace_id,
        user_id: current_user.id,
        threatmetrix_session_id: idv_session.threatmetrix_session_id,
        request_ip: request.remote_ip,
        ipp_enrollment_in_progress: ipp_enrollment_in_progress?,
        proofing_components: ProofingComponents.new(idv_session:),
        proofing_vendor:,
      )

      return true
    end

    def log_event_for_missing_threatmetrix_session_id
      return if self.class.threatmetrix_session_id_present_or_not_required?(idv_session:)
      analytics.idv_verify_info_missing_threatmetrix_session_id if idv_session.ssn_step_complete?
    end

    def best_effort_phone
      if idv_session.phone_for_mobile_flow
        { source: :hybrid_handoff, phone: idv_session.phone_for_mobile_flow }
      elsif current_user.default_phone_configuration
        { source: :mfa, phone: current_user.default_phone_configuration.formatted_phone }
      end
    end

    def proofing_vendor
      @proofing_vendor ||= begin
        # if proofing vendor A/B test is disabled, return default vendor
        ab_test_bucket(:PROOFING_VENDOR) || IdentityConfig.store.idv_resolution_default_vendor
      end
    end

    private

    def ipp_enrollment_in_progress?
      current_user.has_in_person_enrollment?
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

    def idv_failure(failures)
      if ssn_rate_limiter.limited?
        rate_limit_redirect!(:proof_ssn, step_name: STEP_NAME)
      elsif resolution_rate_limiter.limited?
        rate_limit_redirect!(:idv_resolution, step_name: STEP_NAME)
      elsif failures.has_exception? && failures.mva_exception?
        idv_failure_log_warning
        redirect_to state_id_warning_url
      elsif failures.has_exception? && failures.address_exception?
        idv_failure_log_address_warning
        redirect_to address_warning_url
      elsif (failures.has_exception? && failures.threatmetrix_exception?) ||
            (!failures.has_exception? && failures.resolution_failed?)
        idv_failure_log_warning
        redirect_to warning_url
      elsif failures.has_exception?
        idv_failure_log_error
        redirect_to exception_url
      else
        idv_failure_log_warning
        redirect_to warning_url
      end
    end

    def idv_failure_log_error
      analytics.idv_doc_auth_exception_visited(
        step_name: STEP_NAME,
        remaining_submit_attempts: resolution_rate_limiter.remaining_count,
      )
    end

    def idv_failure_log_address_warning
      analytics.idv_doc_auth_address_warning_visited(
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

    def address_warning_url
      idv_session_errors_address_warning_url(flow: flow_param)
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
        analytics.idv_doc_auth_verify_polling_wait_visited
        render 'shared/wait'
        return
      end

      return if confirm_not_rate_limited_after_doc_auth

      if current_async_state.none?
        analytics.idv_doc_auth_verify_visited(**analytics_arguments)
        render :show
      elsif current_async_state.missing?
        analytics.idv_proofing_resolution_result_missing
        flash.now[:error] = I18n.t('idv.failure.timeout')
        render :show

        delete_async
      end
    end

    def async_state_done(current_async_state)
      create_fraud_review_request_if_needed(current_async_state.result)

      form_response = idv_result_to_form_response(
        result: current_async_state.result,
        state: pii[:state],
        state_id_jurisdiction: pii[:state_id_jurisdiction],
        state_id_number: pii[:state_id_number],
        id_doc_type: pii[:id_doc_type],
        extra: {
          address_edited: !!idv_session.address_edited,
          address_line2_present: !pii[:address2].blank?,
          last_name_spaced: pii[:last_name].split(' ').many?,
          previous_ssn_edit_distance: previous_ssn_edit_distance,
          pii_like_keypaths: [
            [:errors, :ssn],
            [:errors, :state_id_jurisdiction],
            [:proofing_results, :context, :stages, :resolution, :errors, :ssn],
            [:proofing_results, :context, :stages, :residential_address, :errors, :ssn],
            [:proofing_results, :context, :stages, :threatmetrix, :response_body, :first_name],
            [:proofing_results, :context, :stages, :state_id, :state_id_jurisdiction],
            [:proofing_results, :context, :stages, :state_id, :errors, :state_id_jurisdiction],
            [:proofing_results, :biographical_info, :identity_doc_address_state],
            [:proofing_results, :biographical_info, :state_id_jurisdiction],
            [:proofing_results, :biographical_info],
          ],
        },
      )

      threatmetrix_response_body = delete_threatmetrix_response_body(form_response)

      if threatmetrix_response_body.present?
        analytics.idv_threatmetrix_response_body(
          response_body: threatmetrix_response_body,
        )
      end

      summarize_result_and_rate_limit(form_response)

      if form_response.success?
        save_threatmetrix_status(form_response)
        save_source_check_vendor(form_response)
        save_resolution_vendors(form_response)
        move_applicant_to_idv_session
        idv_session.mark_verify_info_step_complete!

        flash[:success] = t('doc_auth.forms.doc_success')
        redirect_to next_step_url
      end
      analytics.idv_doc_auth_verify_proofing_results(**analytics_arguments, **form_response)
      delete_async
    end

    def next_step_url
      return idv_request_letter_url if FeatureManagement.idv_by_mail_only? ||
                                       idv_session.gpo_letter_requested
      idv_phone_url
    end

    def save_resolution_vendors(form_response)
      idv_session.resolution_vendor = form_response.extra.dig(
        :proofing_results,
        :context,
        :stages,
        :resolution,
        :vendor_name,
      )

      idv_session.residential_resolution_vendor = form_response.extra.dig(
        :proofing_results,
        :context,
        :stages,
        :residential_address,
        :vendor_name,
      )
    end

    def save_threatmetrix_status(form_response)
      review_status = form_response.extra.dig(:proofing_results, :threatmetrix_review_status)
      idv_session.threatmetrix_review_status = review_status
    end

    def save_source_check_vendor(form_response)
      vendor = form_response.extra.dig(
        :proofing_results,
        :context,
        :stages,
        :state_id,
        :vendor_name,
      )
      idv_session.source_check_vendor = vendor
    end

    def summarize_result_and_rate_limit(summary_result)
      proofing_results_exception = summary_result.extra.dig(:proofing_results, :exception)
      resolution_rate_limiter.increment! if proofing_results_exception.blank?

      failures = VerificationFailures.new(result: summary_result)

      log_verification_attempt(
        success: summary_result.success?,
        failure_reason: failures.formatted_failure_reasons,
      )

      if !summary_result.success?
        idv_failure(failures)
      end
    end

    def load_async_state
      dcs_uuid = idv_session.verify_info_step_document_capture_session_uuid
      return ProofingSessionAsyncResult.none if dcs_uuid.nil?

      dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
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
      id_doc_type: nil,
      extra: {}
    )
      state_id = result.dig(:context, :stages, :state_id)
      if state_id
        state_id[:state] = state if state
        state_id[:state_id_jurisdiction] = state_id_jurisdiction if state_id_jurisdiction
        state_id[:id_doc_type] = id_doc_type if id_doc_type
        if state_id_number
          state_id[:state_id_number] =
            StringRedacter.redact_alphanumeric(state_id_number)
        end
      end

      FormResponse.new(
        success: result[:success],
        errors: result[:errors],
        extra: extra.merge(
          proofing_results: {
            **result.except(:errors, :success),
            biographical_info: result[:biographical_info]&.except(:same_address_as_id),
          },
        ),
      )
    end

    def create_fraud_review_request_if_needed(result)
      return unless FeatureManagement.proofing_device_profiling_collecting_enabled?

      threatmetrix_result = result.dig(:context, :stages, :threatmetrix)
      return unless threatmetrix_result

      success = (threatmetrix_result[:review_status] == 'pass')

      attempts_api_tracker.idv_device_risk_assessment(
        success:,
        failure_reason: device_risk_failure_reason(success, threatmetrix_result),
      )

      return if success

      FraudReviewRequest.create(
        user: current_user,
        login_session_id: Digest::SHA1.hexdigest(current_user.unique_session_id.to_s),
      )
    end

    def move_applicant_to_idv_session
      idv_session.applicant = pii
      idv_session.applicant[:ssn] = idv_session.ssn
      idv_session.applicant['uuid'] = current_user.uuid
    end

    def delete_threatmetrix_response_body(form_response)
      threatmetrix_result = form_response.extra.dig(
        :proofing_results,
        :context,
        :stages,
        :threatmetrix,
      )
      return if threatmetrix_result.blank?

      threatmetrix_result.delete(:response_body)
    end

    def device_risk_failure_reason(success, result)
      return nil if success

      fraud_risk_summary_reason_code = result.dig(
        :response_body,
        :tmx_summary_reason_code,
      ) || ['Fraud risk assessment has failed for unknown reasons']

      { fraud_risk_summary_reason_code: }
    end

    def add_cost(token, transaction_id: nil)
      Db::SpCost::AddSpCost.call(current_sp, token, transaction_id: transaction_id)
    end

    def log_verification_attempt(success:, failure_reason: nil)
      pii_from_doc = pii || {}

      attempts_api_tracker.idv_verification_submitted(
        success: success,
        document_state: pii_from_doc[:state],
        document_number: pii_from_doc[:state_id_number],
        document_issued: pii_from_doc[:state_id_issued],
        document_expiration: pii_from_doc[:state_id_expiration],
        first_name: pii_from_doc[:first_name],
        last_name: pii_from_doc[:last_name],
        date_of_birth: pii_from_doc[:dob],
        address1: pii_from_doc[:address1],
        address2: pii_from_doc[:address2],
        ssn: idv_session.ssn,
        city: pii_from_doc[:city],
        state: pii_from_doc[:state],
        zip: pii_from_doc[:zip],
        failure_reason:,
      )
    end

    VerificationFailures = Struct.new(
      :result,
      keyword_init: true,
    ) do
      def address_exception?
        resolution_failed? &&
          resolution_stage_attributes_requiring_additional_verification == ['address']
      end

      def has_exception?
        result.extra.dig(:proofing_results, :exception).present?
      end

      def mva_exception?
        state_id_stage[:mva_exception].present?
      end

      def threatmetrix_exception?
        threatmetrix_stage[:exception].present?
      end

      def resolution_failed?
        !resolution_stage[:success]
      end

      def state_id_stage
        stages.dig(:state_id) || {}
      end

      def threatmetrix_stage
        stages.dig(:threatmetrix) || {}
      end

      def resolution_stage
        stages.dig(:resolution) || {}
      end

      def stages
        @stages ||= result.extra.dig(
          :proofing_results,
          :context,
          :stages,
        ) || {}
      end

      def resolution_stage_attributes_requiring_additional_verification
        resolution_stage[:attributes_requiring_additional_verification]
      end

      def attributes_requiring_additional_verification
        # grab all the attributes that require additional verification across stages
        stages.map { |_k, v| v[:attributes_requiring_additional_verification] }.flatten.compact
      end

      def failed_stages
        stages.keys.select { |k| !stages[k][:success] }.map do |stage|
          stage == :threatmetrix ? :device_risk_assesment : stage
        end
      end

      def resolution_adjudication_reason
        {
          resolution_adjudication_reason: [
            result.extra.dig(:proofing_results, :context, :resolution_adjudication_reason),
          ],
        }
      end

      def device_profiling_adjudication_reason
        if threatmetrix_stage[:review_status] != 'pass'
          {
            device_profiling_adjudication_reason: [
              result.extra.dig(:proofing_results, :context, :device_profiling_adjudication_reason),
            ],
          }
        else
          {}
        end
      end

      def formatted_failure_reasons
        return nil if result.success? && !failed_stages.present?

        {
          failed_stages:,
          attributes_requiring_additional_verification:,
        }
          .merge(resolution_adjudication_reason)
          .merge(device_profiling_adjudication_reason)
          .compact_blank
      end
    end
  end
end
