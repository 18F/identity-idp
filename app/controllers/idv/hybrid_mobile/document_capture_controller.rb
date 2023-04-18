module Idv
  module HybridMobile
    class DocumentCaptureController < ApplicationController
      include HybridMobileConcern

      before_action :check_valid_document_capture_session

      def show
        increment_step_counts

        analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

        render :show, locals: extra_view_variables
      end

      def update
        handle_stored_result

        analytics.idv_doc_auth_document_capture_submitted(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
          call('document_capture', :update, true)

        redirect_to idv_hybrid_mobile_capture_complete_url
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

      # @param [DocAuth::Response,
      #   DocumentCaptureSessionAsyncResult,
      #   DocumentCaptureSessionResult] response
      def extract_pii_from_doc(response, store_in_session: false)
        pii_from_doc = response.pii_from_doc.merge(
          uuid: effective_user.uuid,
          phone: effective_user.phone_configurations.take&.phone,
          uuid_prefix: ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id,
        )

        flow_session[:had_barcode_read_failure] = response.attention_with_barcode?
        if store_in_session
          flow_session[:pii_from_doc] ||= {}
          flow_session[:pii_from_doc].merge!(pii_from_doc)
          idv_session.delete('applicant')
        end
        track_document_state(pii_from_doc[:state])
      end

      # copied from Flow::Failure module
      def failure(message, extra = nil)
        flow_session[:error_message] = message
        form_response_params = { success: false, errors: { message: message } }
        form_response_params[:extra] = extra unless extra.nil?
        FormResponse.new(**form_response_params)
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

      def save_proofing_components
        return unless current_user

        doc_auth_vendor = DocAuthRouter.doc_auth_vendor(
          discriminator: document_capture_session_uuid,
          analytics: analytics,
        )

        component_attributes = {
          document_check: doc_auth_vendor,
          document_type: 'state_id',
        }
        ProofingComponent.create_or_find_by(user: current_user).update(component_attributes)
      end

      def stored_result
        @stored_result ||= document_capture_session.load_result
      end

      def track_document_state(state)
        return unless IdentityConfig.store.state_tracking_enabled && state
        doc_auth_log = DocAuthLog.find_by(user_id: document_capture_user.id)
        return unless doc_auth_log
        doc_auth_log.state = state
        doc_auth_log.save!
      end
    end
  end
end
