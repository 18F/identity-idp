module Idv
  module Steps
    class VerifyStep < VerifyBaseStep
      State = Struct.new(:status, :pii, :result)

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
        return State.new(:none, nil, nil) if dcs_uuid == nil
        return State.new(:timed_out, nil, nil) if dcs == nil

        proofing_job_result = dcs.load_proofing_result
        return State.new(:timed_out, nil, nil) if proofing_job_result == nil

        if proofing_job_result.result
          proofing_result = convert_job_result(proofing_job_result)
          State.new(:done, proofing_result.pii, proofing_result.result)
        elsif dcs.pii
          State.new(:in_progress, nil, nil)
        end
      end

      private

      # Converts result hash into Proofer::Result and
      # pii into hash to hash with indifferent access.
      #
      # This is because the flow expects result class instances
      # but job results can't serialize/deserialize those.
      # @param [ProofingDocumentCaptureSessionResult]
      # @return [ProofingDocumentCaptureSessionResult]
      def convert_job_result(proofing_job_result)
        # proofer_result = ::Proofer::Result.new(
        #   errors: proofing_job_result.result['errors'],
        #   messages: Set.new(proofing_job_result.result['messages']),
        #   context: proofing_job_result.result['context'].with_indifferent_access,
        #   exception: proofing_job_result.result['exception']
        # )
        result = proofing_job_result.result.with_indifferent_access
        result[:context] = result[:context].with_indifferent_access
        result[:context][:stages] = result[:context][:stages].map(&:with_indifferent_access)

        ProofingDocumentCaptureSessionResult.new(
          id: proofing_job_result.id,
          result: result,
          pii: proofing_job_result.pii.with_indifferent_access,
        )
      end

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
