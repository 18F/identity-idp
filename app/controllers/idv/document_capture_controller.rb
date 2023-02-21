module Idv
  class DocumentCaptureController < ApplicationController
    include IdvSession
    include StepIndicatorConcern
    include StepUtilitiesConcern

    before_action :render_404_if_document_capture_controller_disabled
    before_action :confirm_two_factor_authenticated

    def show
      increment_step_counts

      analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

      render :show, locals: extra_view_variables
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

    def render_404_if_document_capture_controller_disabled
      render_not_found unless IdentityConfig.store.doc_auth_document_capture_controller_enabled
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'document capture',
        step_count: current_flow_step_counts['Idv::Steps::DocumentCaptureStep'],
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(**acuant_sdk_ab_test_analytics_args)
    end

    def current_flow_step_counts
      user_session['idv/doc_auth_flow_step_counts'] ||= {}
      user_session['idv/doc_auth_flow_step_counts'].default = 0
      user_session['idv/doc_auth_flow_step_counts']
    end

    def increment_step_counts
      current_flow_step_counts['Idv::Steps::DocumentCaptureStep'] += 1
    end

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
        in_person_cta_variant_testing_enabled:
        IdentityConfig.store.in_person_cta_variant_testing_enabled,
        in_person_cta_variant_active: bucket,
      }
    end
  end
end
