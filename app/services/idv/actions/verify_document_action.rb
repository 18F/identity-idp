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
          analytics: @flow.analytics,
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

        document_attributes = image_params.slice(
          'encryption_key', 'front_image_iv', 'back_image_iv', 'selfie_image_iv', 'front_image_url',
          'back_image_url', 'selfie_image_url'
        ).to_h

        Idv::Agent.new(document_attributes).proof_document(
          verify_document_capture_session,
          liveness_checking_enabled: liveness_checking_enabled?,
          trace_id: amzn_trace_id,
          analytics_data: {
            client_image_metrics: image_metadata,
            browser_attributes: @flow.analytics.browser_attributes,
          },
        )

        nil
      end

      private

      def image_params
        params.permit(
          ['encryption_key', 'front_image_iv', 'back_image_iv', 'selfie_image_iv',
           'front_image_url', 'back_image_url', 'selfie_image_url'],
        )
      end

      def image_metadata
        params.permit(:front_image_metadata, :back_image_metadata).
          to_h.
          transform_values do |str|
            JSON.parse(str)
        rescue JSON::ParserError
            nil
          end.
          compact.
          transform_keys { |key| key.gsub(/_image_metadata$/, '') }.
          deep_symbolize_keys
      end
    end
  end
end
