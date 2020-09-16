module Idv
  module Steps
    class VerifyStep < VerifyBaseStep
      State = Struct.new(:status, :result)

      def call
        case async_state.status
        when :none
          enqueue_job
        when :in_progress
          nil
        when :timed_out
          enqueue_job
        when :done
          nil
        end
      end

      def after_call
        binding.pry
        result = check_ssn(pii_from_doc) if result.success?
        summarize_result_and_throttle_failures(result)
      end

      def async?
        true
      end

      # @return [State] async state
      def async_state
        dcs_uuid = flow_session[:idv_verify_step_document_capture_session_uuid]
        dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
        return State.new(:none, nil) if dcs_uuid == nil
        return State.new(:timed_out, nil) if dcs == nil

        proofing_result = dcs.load_proofing_result

        if proofing_result.result
          State.new(:done, proofing_result)
        elsif dcs.pii
          State.new(:in_progress, nil)
        end
      end

      private

      def enqueue_job
        pii_from_doc = flow_session[:pii_from_doc]

        document_capture_session = DocumentCaptureSession.create(user_id: user_id,
                                                                 requested_at: Time.zone.now)
        document_capture_session.store_proofing_pii_from_doc(pii_from_doc)

        flow_session[:idv_verify_step_document_capture_session_uuid] = document_capture_session.uuid

        stages = should_use_aamva?(pii_from_doc) ? %w[resolution state_id] : ['resolution']
        VendorProofJob.perform_later(document_capture_session.uuid, stages)
      end
    end
  end
end
