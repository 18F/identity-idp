module Idv
  module Steps
    class VerifyStep < VerifyBaseStep
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

      def after_call(pii, idv_result)
        # binding.pry

        add_proofing_costs(idv_result)
        response = idv_result_to_form_response(idv_result)
        response = check_ssn(pii) if response.success?
        summarize_result_and_throttle_failures(response)
      end

      def async?
        true
      end

      # @return [State]
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
        elsif dcs.pii
          State.in_progress
        end
      end

      def delete_async
        flow_session.delete(:idv_verify_step_document_capture_session_uuid)
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
