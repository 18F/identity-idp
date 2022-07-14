module Idv
  module Actions
    class VerifyDocumentStatusAction < Idv::Steps::VerifyBaseStep
      def call
        process_async_state(async_state)
      end

      private

      def process_async_state(current_async_state)
        form = ApiDocumentVerificationStatusForm.new(
          async_state: current_async_state,
          document_capture_session: verify_document_capture_session,
        )

        form_response = form.submit

        if current_async_state.done?
          process_result(current_async_state)

          if form_response.success?
            async_result_response = async_state_done(current_async_state)
            form_response = async_result_response.merge(form_response)
          end
        end

        presenter = ImageUploadResponsePresenter.new(
          form_response: form_response,
          url_options: url_options,
        )

        status = :accepted if current_async_state.in_progress?

        render_json(
          presenter,
          status: status || presenter.status,
        )

        form_response
      end

      # @param [ProofingSessionAsyncResult] async_result
      def async_state_done(async_result)
        doc_pii_form_result = Idv::DocPiiForm.new(
          pii: async_result.pii,
          attention_with_barcode: async_result.attention_with_barcode?,
        ).submit

        @flow.analytics.idv_doc_auth_submitted_pii_validation(
          **doc_pii_form_result.to_h.merge(
            remaining_attempts: remaining_attempts,
            flow_path: flow_path,
          ),
        )

        if doc_pii_form_result.success?
          extract_pii_from_doc(async_result, store_in_session: !hybrid_flow_mobile?)

          mark_step_complete(:document_capture)
          save_proofing_components
        end

        doc_pii_form_result
      end

      def process_result(async_state)
        add_costs(async_state.result)
      end

      def verify_document_capture_session
        return nil unless document_capture_session_uuid
        return @verify_document_capture_session if defined?(@verify_document_capture_session)
        @verify_document_capture_session = DocumentCaptureSession.find_by(
          uuid: document_capture_session_uuid,
        )
      end

      def document_capture_session_uuid
        params[:document_capture_session_uuid]
      end

      def async_state
        if verify_document_capture_session.nil?
          document_capture_analytics('failed to load verify_document_capture_session')

          return missing
        end

        proofing_job_result = verify_document_capture_session.load_doc_auth_async_result
        if proofing_job_result.nil?
          @flow.analytics.doc_auth_async(
            error: 'failed to load async result',
            uuid: verify_document_capture_session.uuid,
            result_id: verify_document_capture_session.result_id,
          )
          return missing
        end

        proofing_job_result
      end

      def remaining_attempts
        return nil unless verify_document_capture_session
        Throttle.new(
          user: verify_document_capture_session.user,
          throttle_type: :idv_doc_auth,
        ).remaining_count
      end

      def missing
        @flow.analytics.proofing_document_result_missing
        DocumentCaptureSessionAsyncResult.missing
      end

      def document_capture_analytics(message)
        @flow.analytics.doc_auth_async(
          error: message,
          uuid: document_capture_session_uuid,
        )
      end
    end
  end
end
