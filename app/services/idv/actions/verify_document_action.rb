module Idv
  module Actions
    class VerifyDocumentAction < Idv::Steps::DocAuthBaseStep
      def call
        enqueue_job
      end

      private

      def form_submit
        response = form.submit
        presenter = ImageUploadResponsePresenter.new(
          form: form,
          form_response: response,
          url_options: url_options,
        )
        status = :accepted if response.success?
        render_json(
          presenter,
          status: status || presenter.status,
        )
        response
      end

      def form
        @form ||= Idv::ApiDocumentVerificationForm.new(
          params,
          liveness_checking_enabled: liveness_checking_enabled?,
        )
      end

      def enqueue_job
        verify_document_capture_session = if hybrid_flow_mobile?
          document_capture_session
        else
          create_document_capture_session(
            verify_document_capture_session_uuid_key,
          )
        end
        verify_document_capture_session.requested_at = Time.zone.now
        verify_document_capture_session.create_doc_auth_session

        applicant = image_params.to_h.slice(
          'encryption_key', 'front_image_iv', 'back_image_iv', 'selfie_image_iv', 'front_image_url',
          'back_image_url', 'selfie_image_url'
        )

        Idv::Agent.new(applicant).proof_document(
          verify_document_capture_session,
          liveness_checking_enabled: liveness_checking_enabled?,
          trace_id: amzn_trace_id,
        )

        nil
      end

      private

      def image_params
        params.permit([
          :encryption_key, :front_image_iv, :back_image_iv, :selfie_image_iv,
          :front_image_url, :back_image_url, :selfie_image_url
        ])
      end
    end
  end
end
