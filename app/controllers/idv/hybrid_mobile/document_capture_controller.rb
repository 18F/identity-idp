# frozen_string_literal: true

module Idv
  module HybridMobile
    class DocumentCaptureController < ApplicationController
      include Idv::AvailabilityConcern
      include DocumentCaptureConcern
      include HybridMobileConcern

      before_action :check_valid_document_capture_session
      before_action :override_csp_to_allow_acuant
      before_action :confirm_document_capture_needed, only: :show
      before_action :set_usps_form_presenter
      before_action -> { redirect_to_correct_vendor(Idp::Constants::Vendors::LEXIS_NEXIS, true) }

      def show
        analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
          call('document_capture', :view, true)

        render :show, locals: extra_view_variables
      end

      def update
        document_capture_session.confirm_ocr
        result = handle_stored_result

        analytics.idv_doc_auth_document_capture_submitted(**result.to_h.merge(analytics_arguments))

        Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
          call('document_capture', :update, true)

        # rate limiting redirect is in ImageUploadResponsePresenter
        if result.success?
          flash[:success] = t('doc_auth.headings.capture_complete')
          redirect_to idv_hybrid_mobile_capture_complete_url
        else
          redirect_to idv_hybrid_mobile_document_capture_url
        end
      end

      def extra_view_variables
        {
          flow_path: 'hybrid',
          mock_client: doc_auth_vendor == 'mock',
          document_capture_session_uuid: document_capture_session_uuid,
          failure_to_proof_url: return_to_sp_failure_to_proof_url(step: 'document_capture'),
          doc_auth_selfie_capture: resolved_authn_context_result.facial_match?,
        }.merge(
          acuant_sdk_upgrade_a_b_testing_variables,
        )
      end

      private

      def analytics_arguments
        {
          flow_path: 'hybrid',
          step: 'document_capture',
          analytics_id: 'Doc Auth',
          liveness_checking_required: resolved_authn_context_result.facial_match?,
          selfie_check_required: resolved_authn_context_result.facial_match?,
        }.merge(
          ab_test_analytics_buckets,
        )
      end

      def handle_stored_result
        if stored_result&.success? && selfie_requirement_met?
          save_proofing_components(document_capture_user)
          extract_pii_from_doc(document_capture_user)
          successful_response
        else
          extra = { stored_result_present: stored_result.present? }
          failure(I18n.t('doc_auth.errors.general.network_error'), extra)
        end
      end

      def confirm_document_capture_needed
        return unless stored_result&.success?
        return if redo_document_capture_pending?

        redirect_to idv_hybrid_mobile_capture_complete_url
      end

      def redo_document_capture_pending?
        return unless stored_result&.dig(:captured_at)
        return unless document_capture_session.requested_at

        document_capture_session.requested_at > stored_result.captured_at
      end

      def set_usps_form_presenter
        @presenter = Idv::InPerson::UspsFormPresenter.new
      end
    end
  end
end
