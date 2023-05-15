module Idv
  module HybridMobile
    class DocumentCaptureController < ApplicationController
      include DocumentCaptureConcern
      include HybridMobileConcern

      before_action :check_valid_document_capture_session
      before_action :override_csp_to_allow_acuant

      def show
        if document_capture_session&.load_result&.success?
          redirect_to idv_hybrid_mobile_capture_complete_url
          return
        end

        analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
          call('document_capture', :view, true)

        render :show, locals: extra_view_variables
      end

      def update
        result = handle_stored_result

        analytics.idv_doc_auth_document_capture_submitted(**result.to_h.merge(analytics_arguments))

        Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
          call('document_capture', :update, true)

        if result.success?
          redirect_to idv_hybrid_mobile_capture_complete_url
        else
          redirect_to idv_hybrid_mobile_document_capture_url
        end
      end

      def extra_view_variables
        {
          flow_path: 'hybrid',
          document_capture_session_uuid: document_capture_session_uuid,
          failure_to_proof_url: return_to_sp_failure_to_proof_url(step: 'document_capture'),
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
          analytics_id: 'Doc Auth',
          irs_reproofing: irs_reproofing?,
        }.merge(**acuant_sdk_ab_test_analytics_args)
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

        track_document_state(pii_from_doc[:state])
      end

      # copied from Flow::Failure module
      def failure(message, extra = nil)
        form_response_params = { success: false, errors: { message: message } }
        form_response_params[:extra] = extra unless extra.nil?
        FormResponse.new(**form_response_params)
      end

      def handle_stored_result
        if stored_result&.success?
          save_proofing_components
          extract_pii_from_doc(stored_result)
          successful_response
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

      def stored_result
        @stored_result ||= document_capture_session.load_result
      end

      def successful_response
        FormResponse.new(success: true)
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
