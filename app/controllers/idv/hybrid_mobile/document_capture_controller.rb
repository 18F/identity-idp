module Idv
  module HybridMobile
    class DocumentCaptureController < ApplicationController
      include HybridMobileConcern

      before_action :check_valid_document_capture_session
      before_action :override_csp_to_allow_acuant

      def show
        increment_step_count 'Idv::Steps::DocumentCaptureStep'

        analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
          call('document_capture', :view, true)

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
        # Used to call :verify_document_status in idv/shared/_document_capture.html.erb
        # That code can be updated after the hybrid flow is out of the FSM, and then
        # this can be removed.
        @step_url = :idv_capture_doc_step_url

        url_builder = ImageUploadPresignedUrlGenerator.new

        {
          flow_path: 'hybrid',
          document_capture_session_uuid: document_capture_session_uuid,
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
      def extract_pii_from_doc(response)
        pii_from_doc = response.pii_from_doc.merge(
          uuid: effective_user.uuid,
          phone: effective_user.phone_configurations.take&.phone,
          uuid_prefix: ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id,
        )

        flow_session[:had_barcode_read_failure] = response.attention_with_barcode?

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
          extract_pii_from_doc(stored_result)
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

      def native_camera_ab_testing_variables
        {
          acuant_sdk_upgrade_ab_test_bucket:
            AbTests::ACUANT_SDK.bucket(document_capture_session_uuid),
        }
      end

      def override_csp_to_allow_acuant
        policy = current_content_security_policy
        policy.connect_src(*policy.connect_src, 'us.acas.acuant.net')
        policy.script_src(*policy.script_src, :unsafe_eval)
        policy.style_src(*policy.style_src, :unsafe_inline)
        policy.img_src(*policy.img_src, 'blob:')
        request.content_security_policy = policy
      end

      def save_proofing_components
        return unless document_capture_user

        doc_auth_vendor = DocAuthRouter.doc_auth_vendor(
          discriminator: document_capture_session_uuid,
          analytics: analytics,
        )

        component_attributes = {
          document_check: doc_auth_vendor,
          document_type: 'state_id',
        }

        ProofingComponent.
          create_or_find_by(user: document_capture_user).
          update(component_attributes)
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
