module Idv
  module Steps
    class VerifyStep < VerifyBaseStep
      STEP_INDICATOR_STEP = :verify_info

      def call
        if current_async_state.none?
          enqueue_job
        elsif current_async_state.in_progress?
          render_pending_response
        elsif current_async_state.missing?
          delete_async
          @flow.analytics.idv_proofing_resolution_result_missing
          render_json({ error: I18n.t('idv.failure.timeout') })
          FormResponse.new(success: false)
        elsif current_async_state.done?
          render_json({ redirect_url: idv_url })
          async_state_done
        end
      end

      def extra_view_variables
        {
          pii: pii,
          step_url: method(:idv_doc_auth_step_url),
        }
      end

      private

      def async_state_done
        add_proofing_costs(current_async_state.result)
        form_response = idv_result_to_form_response(
          result: current_async_state.result,
          state: flow_session[:pii_from_doc][:state],
          state_id_jurisdiction: flow_session[:pii_from_doc][:state_id_jurisdiction],
          extra: {
            address_edited: !!flow_session['address_edited'],
            pii_like_keypaths: [[:errors, :ssn]],
          },
        )

        if form_response.success?
          response = check_ssn if form_response.success?
          form_response = form_response.merge(response)
        end
        summarize_result_and_throttle_failures(form_response)
        delete_async

        form_response
      end

      def current_async_state
        return @current_async_state if defined?(@async_state)
        @current_async_state = async_state
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

      def enqueue_job
        return invalid_state_response if invalid_state?

        pii[:uuid_prefix] = ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id

        if pii[:ssn].present?
          throttle = Throttle.new(
            target: Pii::Fingerprinter.fingerprint(pii[:ssn]),
            throttle_type: :proof_ssn,
          )

          if throttle.throttled_else_increment?
            @flow.analytics.track_event(
              Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
              throttle_type: :proof_ssn,
              step_name: self.class,
            )
            render_redirect idv_session_errors_ssn_failure_url
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
        )

        render_pending_response
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

      def render_pending_response
        render_json({ pending: true }, status: :accepted)
        FormResponse.new(success: false, extra: { pending: true })
      end

      def render_redirect(url)
        render_json({ redirect_url: url })
      end
    end
  end
end
