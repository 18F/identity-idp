module Idv
  module Steps
    class DocumentCaptureStep < DocAuthBaseStep
      IMAGE_UPLOAD_PARAM_NAMES = %i[
        front_image back_image
      ].freeze

      def self.analytics_visited_event
        :idv_doc_auth_document_capture_visited
      end

      def self.analytics_submitted_event
        :idv_doc_auth_document_capture_submitted
      end

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
        }.merge(
          native_camera_ab_testing_variables, 
          acuant_sdk_upgrade_a_b_testing_variables,
          in_person_cta_variant_testing_variables,
        )
      end

      private

      def native_camera_ab_testing_variables
        {
          acuant_sdk_upgrade_ab_test_bucket:
            AbTests::ACUANT_SDK.bucket(flow_session[:document_capture_session_uuid]),
        }
      end

      def acuant_sdk_upgrade_a_b_testing_variables
        bucket = AbTests::ACUANT_SDK.bucket(flow_session[:document_capture_session_uuid])
        testing_enabled = IdentityConfig.store.idv_acuant_sdk_upgrade_a_b_testing_enabled
        use_alternate_sdk = (bucket == :use_alternate_sdk)
        if use_alternate_sdk
          acuant_version = IdentityConfig.store.idv_acuant_sdk_version_alternate
        else
          acuant_version = IdentityConfig.store.idv_acuant_sdk_version_default
        end
        {
          acuant_sdk_upgrade_a_b_testing_enabled:
              testing_enabled,
          use_alternate_sdk: use_alternate_sdk,
          acuant_version: acuant_version,
        }
      end

      def in_person_cta_variant_testing_variables
        bucket = AbTests::IN_PERSON_CTA.bucket(flow_session[:document_capture_session_uuid])
        {
          in_person_cta_variant_testing_enabled: IdentityConfig.store.in_person_cta_variant_testing_enabled,
          in_person_cta_variant_active: bucket,
        }
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
