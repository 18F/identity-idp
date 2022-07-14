module Idv
  module Steps
    class VerifyStep < VerifyBaseStep
      STEP_INDICATOR_STEP = :verify_info

      def call
        enqueue_job
      end

      def extra_view_variables
        {
          pii: pii,
          step_url: method(:idv_doc_auth_step_url),
        }
      end

      private

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
            @flow.analytics.track_event(
              Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
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
    end
  end
end
