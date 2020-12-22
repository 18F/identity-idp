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
          document_capture_session: document_capture_session,
        )

        form_response = form.submit

        if current_async_state.done?
          process_result(current_async_state.result)

          if form_response.success?
            async_result_response = async_state_done(current_async_state)
            form_response = async_result_response.merge(form_response)
          end
        end

        presenter = ImageUploadResponsePresenter.new(
          form: form,
          form_response: form_response,
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
        doc_pii_form_result = Idv::DocPiiForm.new(async_result.pii).submit

        delete_async
        if doc_pii_form_result.success?
          extract_pii_from_doc(async_result)

          mark_step_complete(:document_capture)
          save_proofing_components
        end

        doc_pii_form_result
      end

      def process_result(result)
        add_cost(:acuant_result) if result.to_h[:billed]
      end

      def document_capture_session
        return @document_capture_session if defined?(@document_capture_session)
        dcs_uuid = flow_session[verify_document_capture_session_uuid_key]
        @document_capture_session = DocumentCaptureSession.find_by(uuid: dcs_uuid)
      end

      def async_state
        if document_capture_session.nil?
          failed_to_load_document_capture_analytics

          return timed_out
        end

        proofing_job_result = document_capture_session.load_doc_auth_async_result
        if proofing_job_result.nil?
          @flow.analytics.track_event(Analytics::DOC_AUTH_ASYNC,
                                      error: 'failed to load async result',
                                      uuid: document_capture_session.uuid,
                                      result_id: document_capture_session.result_id,
                                     )
          return timed_out
        end

        proofing_job_result
      end

      def timed_out
        delete_async
        DocumentCaptureSessionAsyncResult.timed_out
      end

      def delete_async
        failed_to_load_document_capture_analytics
        flow_session.delete(verify_document_capture_session_uuid_key)
      end

      def failed_to_load_document_capture_analytics
        data = {
          error: 'failed to load document_capture_session',
          uuid: flow_session[verify_document_capture_session_uuid_key],
        }

        if LoginGov::Hostdata.env == 'dev'
          data.merge!(
            flow_session: flow_session.except(:pii_from_doc),
            flow_session_keys: flow_session.keys,
          )
        end

        @flow.analytics.track_event(Analytics::DOC_AUTH_ASYNC, data)
      end
    end
  end
end
