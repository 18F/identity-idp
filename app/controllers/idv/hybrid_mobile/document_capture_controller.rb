module Idv
  module HybridMobile
    class DocumentCaptureController < ApplicationController
      include HybridMobileConcern

      before_action :check_valid_document_capture_session

      def show
        increment_step_counts

        analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

        render(
          template: 'layouts/flow_step',
          locals: {
            step_template: 'idv/capture_doc/document_capture',
            flow_namespace: 'idv',
            flow_session: {},
          }.merge(extra_view_variables),
        )
      end

      def update
        raise 'NOT IMPLEMENTED'
      end

      def extra_view_variables
        url_builder = ImageUploadPresignedUrlGenerator.new

        {
          front_image_upload_url: url_builder.presigned_image_upload_url(
            image_type: 'front',
            transaction_id: document_capture_session_uuid,
          ),
          back_image_upload_url: url_builder.presigned_image_upload_url(
            image_type: 'back',
            transaction_id: document_capture_session_uuid,
          ),
        }.merge(
          native_camera_ab_testing_variables,
          acuant_sdk_upgrade_a_b_testing_variables,
          in_person_cta_variant_testing_variables,
        )
      end

      private

      def acuant_sdk_ab_test_analytics_args
        {
          acuant_sdk_upgrade_ab_test_bucket:
            AbTests::ACUANT_SDK.bucket(document_capture_session_uuid),
        }
      end

      def acuant_sdk_upgrade_a_b_testing_variables
        bucket = AbTests::ACUANT_SDK.bucket(document_capture_session_uuid)
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

      def analytics_arguments
        {
          flow_path: 'hybrid',
          step: 'document_capture',
          step_count: current_flow_step_counts['Idv::Steps::DocumentCaptureStep'],
          analytics_id: 'Doc Auth',
          irs_reproofing: irs_reproofing?,
        }.merge(**acuant_sdk_ab_test_analytics_args)
      end

      def current_flow_step_counts
        session['idv/doc_auth_flow_step_counts'] ||= {}
        session['idv/doc_auth_flow_step_counts'].default = 0
        session['idv/doc_auth_flow_step_counts']
      end

      def in_person_cta_variant_testing_variables
        bucket = AbTests::IN_PERSON_CTA.bucket(document_capture_session_uuid)
        session[:in_person_cta_variant] = bucket
        {
          in_person_cta_variant_testing_enabled:
          IdentityConfig.store.in_person_cta_variant_testing_enabled,
          in_person_cta_variant_active: bucket,
        }
      end

      def increment_step_counts
        current_flow_step_counts['Idv::Steps::DocumentCaptureStep'] += 1
      end

      def irs_reproofing?
        document_capture_user.reproof_for_irs?(
          service_provider: current_sp,
        ).present?
      end

      def native_camera_ab_testing_variables
        {
          acuant_sdk_upgrade_ab_test_bucket:
            AbTests::ACUANT_SDK.bucket(document_capture_session_uuid),
        }
      end
    end
  end
end
