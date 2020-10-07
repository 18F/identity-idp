module Idv
  module Steps
    class VerifyWaitStepShow < VerifyBaseStep
      State = Struct.new(:status, :pii, :result, keyword_init: true) do
        def self.none
          new(status: :none)
        end

        def self.timed_out
          new(status: :timed_out)
        end

        def self.in_progress
          new(status: :in_progress)
        end

        def self.done(pii:, result:)
          new(status: :done, pii: pii, result: result)
        end

        private_class_method :new
      end

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
        dcs_uuid = flow_session[:idv_verify_step_document_capture_session_uuid]
        dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
        return State.none if dcs_uuid.nil?
        return State.timed_out if dcs.nil?

        proofing_job_result = dcs.load_proofing_result
        return State.timed_out if proofing_job_result.nil?

        if proofing_job_result.result
          proofing_job_result.result.deep_symbolize_keys!
          proofing_job_result.pii.deep_symbolize_keys!
          State.done(pii: proofing_job_result.pii, result: proofing_job_result.result)
        elsif proofing_job_result.pii
          State.in_progress
        end
      end

      def delete_async
        flow_session.delete(:idv_verify_step_document_capture_session_uuid)
      end
    end
  end
end
