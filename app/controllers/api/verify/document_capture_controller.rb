module Api
  module Verify
    class DocumentCaptureController < BaseController
      self.required_step = 'document_capture'
      include ApplicationHelper

      def create
        result = @form ||= Idv::ApiDocumentVerificationForm.new(
          verify_params,
          liveness_checking_enabled: liveness_checking_enabled?,
          analytics: analytics,
        ).submit

        if result.success?
          enqueue_job

          render json: {
            status: 'in_progress',
          }, status: :ok
        else
          render json: { error: result.errors }, status: :bad_request
        end
      end

      private

      def enqueue_job
        verify_document_capture_session = DocumentCaptureSession.
          find_by(uuid: params[:document_capture_session_uuid])
        verify_document_capture_session.requested_at = Time.zone.now
        verify_document_capture_session.create_doc_auth_session

        document_attributes = verify_params.to_h
        applicant_pii = {}
        applicant = {
          user_uuid: applicant_pii[:uuid],
          uuid_prefix: applicant_pii[:uuid_prefix],
          document_arguments: document_attributes,
        }
        Idv::Agent.new(applicant).proof_document(
          verify_document_capture_session,
          liveness_checking_enabled: liveness_checking_enabled?,
          trace_id: amzn_trace_id,
          image_metadata: image_metadata,
          analytics_data: {
            browser_attributes: analytics.browser_attributes,
          },
          flow_path: params[:flow_path],
        )
        nil
      end

      def verify_params
        params.permit(
          :encryption_key,
          :front_image_iv,
          :back_image_iv,
          :selfie_image_iv,
          :front_image_url,
          :back_image_url,
          :selfie_image_url,
          :document_capture_session_uuid,
          :flow_path,
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
