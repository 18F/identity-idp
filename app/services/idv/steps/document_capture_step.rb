module Idv
  module Steps
    class DocumentCaptureStep < DocAuthBaseStep
      IMAGE_UPLOAD_PARAM_NAMES = %i[
        front_image back_image selfie_image
      ].freeze

      def call
        handle_stored_result if !FeatureManagement.document_capture_async_uploads_enabled?
      end

      def extra_view_variables
        url_builder = ImageUploadPresignedUrlGenerator.new

        {
          front_image_upload_url: url_builder.presigned_image_upload_url(
            image_type: 'front',
            transaction_id: flow_session[:document_capture_session_uuid],
          ),
          back_image_upload_url: url_builder.presigned_image_upload_url(
            image_type: 'back',
            transaction_id: flow_session[:document_capture_session_uuid],
          ),
          selfie_image_upload_url: url_builder.presigned_image_upload_url(
            image_type: 'selfie',
            transaction_id: flow_session[:document_capture_session_uuid],
          ),
        }.merge(native_camera_ab_testing_variables)
      end

      private

      def native_camera_ab_testing_variables
        skip_sdk = randomize?(
          IdentityConfig.store.idv_native_camera_a_b_testing_percent,
          flow_session[:document_capture_session_uuid],
        )

        {
          native_camera_a_b_testing_enabled:
            IdentityConfig.store.idv_native_camera_a_b_testing_enabled,
          native_camera_only: skip_sdk,
        }
      end

      def randomize?(target_percent, discriminator)
        return false if discriminator.blank?

        max_sha = (16 ** 64) - 1
        user_value = Digest::SHA256.hexdigest(discriminator).to_i(16).to_f / max_sha * 100

        user_value < target_percent.clamp(0, 100)
      end

      def handle_stored_result
        if stored_result&.success?
          save_proofing_components
          extract_pii_from_doc(stored_result, store_in_session: !hybrid_flow_mobile?)
        else
          extra = { stored_result_present: stored_result.present? }
          failure(I18n.t('doc_auth.errors.general.network_error'), extra)
        end
      end

      def stored_result
        return @stored_result if defined?(@stored_result)
        @stored_result = document_capture_session&.load_result
      end
    end
  end
end
