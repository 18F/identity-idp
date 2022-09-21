module Idv
  module Steps
    class VerifyBaseStep < DocAuthBaseStep
      private

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
        idv_session['applicant'] = pii
        idv_session['applicant']['uuid'] = current_user.uuid
      end

      def skip_legacy_steps
        idv_session['profile_confirmation'] = true
        idv_session['vendor_phone_confirmation'] = false
        idv_session['user_phone_confirmation'] = false
        idv_session['address_verification_mechanism'] = 'phone'
        idv_session['resolution_successful'] = 'phone'
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
            add_cost(:threatmetrix, transaction_id: tmx_id) if tmx_id
          end
        end
      end

      def pii
        raise NotImplementedError
      end

      def delete_pii
        raise NotImplementedError
      end

      def throttle
        @throttle ||= Throttle.new(
          user: current_user,
          throttle_type: :idv_resolution,
        )
      end

      def idv_failure(result)
        throttle.increment! if result.extra.dig(:proofing_results, :exception).blank?
        if throttle.throttled?
          @flow.irs_attempts_api_tracker.idv_verification_rate_limited
          @flow.analytics.throttler_rate_limit_triggered(
            throttle_type: :idv_resolution,
            step_name: self.class.name,
          )
          redirect_to idv_session_errors_failure_url
        elsif result.extra.dig(:proofing_results, :exception).present?
          @flow.analytics.idv_doc_auth_exception_visited(
            step_name: self.class.name,
            remaining_attempts: throttle.remaining_count,
          )
          redirect_to exception_url
        else
          @flow.analytics.idv_doc_auth_warning_visited(
            step_name: self.class.name,
            remaining_attempts: throttle.remaining_count,
          )
          redirect_to warning_url
        end
        result
      end

      def exception_url
        idv_session_errors_exception_url
      end

      def warning_url
        idv_session_errors_warning_url
      end

      def idv_success(idv_result)
        idv_result[:success]
      end

      def idv_errors(idv_result)
        idv_result[:errors]
      end

      def idv_extra(idv_result)
        idv_result.except(:errors, :success)
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

      def process_aamva(transaction_id)
        # transaction_id comes from TransactionLocatorId
        add_cost(:aamva, transaction_id: transaction_id)
        track_aamva
      end

      def track_aamva
        return unless IdentityConfig.store.state_tracking_enabled
        doc_auth_log = DocAuthLog.find_by(user_id: user_id)
        return unless doc_auth_log
        doc_auth_log.aamva = true
        doc_auth_log.save!
      end

      def enqueue_job
        return if flow_session[verify_step_document_capture_session_uuid_key]
        return invalid_state_response if invalid_state?

        pii[:uuid_prefix] = ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id

        if pii[:ssn].present?
          throttle = Throttle.new(
            target: Pii::Fingerprinter.fingerprint(pii[:ssn]),
            throttle_type: :proof_ssn,
          )

          if throttle.throttled_else_increment?
            @flow.analytics.throttler_rate_limit_triggered(
              throttle_type: :proof_ssn,
              step_name: self.class,
            )
            redirect_to idv_session_errors_ssn_failure_url
            return
          end
        end

        document_capture_session = create_document_capture_session(
          verify_step_document_capture_session_uuid_key,
        )

        document_capture_session.requested_at = Time.zone.now

        idv_agent.proof_resolution(
          document_capture_session,
          should_proof_state_id: should_use_aamva?(pii),
          trace_id: amzn_trace_id,
          user_id: user_id,
          threatmetrix_session_id: flow_session[:threatmetrix_session_id],
          request_ip: request.remote_ip,
          issuer: sp_session[:issuer],
        )
      end

      def idv_agent
        @idv_agent ||= Idv::Agent.new(pii)
      end

      def invalid_state?
        pii.blank?
      end

      def invalid_state_response
        mark_step_incomplete(:ssn)
        FormResponse.new(success: false)
      end

      def process_async_state(current_async_state)
        if current_async_state.none?
          mark_step_incomplete(:verify)
        elsif current_async_state.in_progress?
          nil
        elsif current_async_state.missing?
          flash[:error] = I18n.t('idv.failure.timeout')
          delete_async
          mark_step_incomplete(:verify)
          @flow.analytics.idv_proofing_resolution_result_missing
        elsif current_async_state.done?
          async_state_done(current_async_state)
        end
      end

      def async_state_done(current_async_state)
        add_proofing_costs(current_async_state.result)
        form_response = idv_result_to_form_response(
          result: current_async_state.result,
          state: pii[:state],
          state_id_jurisdiction: pii[:state_id_jurisdiction],
          # todo: add other edited fields?
          extra: {
            address_edited: !!flow_session['address_edited'],
            pii_like_keypaths: [[:errors, :ssn]],
          },
        )
        pii_from_doc = pii || {}
        @flow.irs_attempts_api_tracker.idv_verification_submitted(
          success: form_response.success?,
          document_state: pii_from_doc[:state],
          document_number: pii_from_doc[:state_id_number],
          document_issued: pii_from_doc[:state_id_issued],
          document_expiration: pii_from_doc[:state_id_expiration],
          first_name: pii_from_doc[:first_name],
          last_name: pii_from_doc[:last_name],
          date_of_birth: pii_from_doc[:dob],
          address: pii_from_doc[:address1],
          ssn: pii_from_doc[:ssn],
          failure_reason: form_response.to_h[:error_details] || result.errors.presence,
        )

        if form_response.success?
          response = check_ssn
          form_response = form_response.merge(response)
        end
        summarize_result_and_throttle_failures(form_response)
        delete_async

        if form_response.success?
          mark_step_complete(:verify_wait)
        else
          mark_step_incomplete(:verify)
        end

        form_response
      end

      def async_state
        dcs_uuid = flow_session[verify_step_document_capture_session_uuid_key]
        dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
        return ProofingSessionAsyncResult.none if dcs_uuid.nil?
        return ProofingSessionAsyncResult.missing if dcs.nil?

        proofing_job_result = dcs.load_proofing_result
        return ProofingSessionAsyncResult.missing if proofing_job_result.nil?

        proofing_job_result
      end

      def delete_async
        flow_session.delete(verify_step_document_capture_session_uuid_key)
      end

      def idv_result_to_form_response(result:, state: nil, state_id_jurisdiction: nil, extra: {})
        state_id = result.dig(:context, :stages, :state_id)
        if state_id
          state_id[:state] = state if state
          state_id[:state_id_jurisdiction] = state_id_jurisdiction if state_id_jurisdiction
        end
        FormResponse.new(
          success: idv_success(result),
          errors: idv_errors(result),
          extra: extra.merge(proofing_results: idv_extra(result)),
        )
      end
    end
  end
end
