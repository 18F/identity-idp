# frozen_string_literal: true

module Idv
  module HybridMobile
    class DocumentCaptureController < ApplicationController
      include Idv::AvailabilityConcern
      include DocumentCaptureConcern
      include HybridMobileConcern
      include Idv::SocureConcern

      before_action :check_valid_document_capture_session
      before_action :override_csp_to_allow_acuant
      before_action :confirm_document_capture_needed, only: :show
      before_action :set_usps_form_presenter

      def show
        # analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

        # Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
        #   call('document_capture', :view, true)

        # render :show, locals: extra_view_variables

        redirect_to idv_hybrid_mobile_document_capture_socure_url
      end

      def show_socure
        analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
          call('document_capture', :view, true)

        # render :show, locals: extra_view_variables

        doc_req = DocAuth::Socure::Requests::DocumentRequest.new(
          document_capture_session_uuid: document_capture_session_uuid,
          redirect_url: idv_hybrid_mobile_document_capture_socure_redirect_url,
          verification_level: request.params['verification_level'],
        )
        doc_resp = doc_req.fetch

        @url = doc_resp.dig('data', 'url')
        @msg = doc_resp['msg']
        @reference_id = doc_resp.dig('referenceId')
        @qr_code = nil

        unless Rails.env.development?
          redirect_to @url, allow_other_host: true if @url
        end
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

      def socure_redirect
        # fetch result
        if (socure_document_uuid = request.params[:document_uuid])
          uploaded_documents_decision(socure_document_uuid)
        end

        document_capture_session.confirm_ocr
        result = handle_stored_result

        analytics.idv_doc_auth_document_capture_submitted(**result.to_h.merge(analytics_arguments))

        Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
          call('document_capture', :update, true)

        # rate limiting redirect is in ImageUploadResponsePresenter
        if result.success?
          # flash[:success] = t('doc_auth.headings.capture_complete')
          redirect_to idv_hybrid_mobile_capture_complete_url
        else
          redirect_to idv_hybrid_mobile_document_capture_warning_url
        end
      end

      def warning
        @remaining_submit_attempts = 5 # rate_limiter.remaining_count
        @try_again_path = idv_hybrid_mobile_document_capture_url
      end

      def extra_view_variables
        {
          flow_path: 'hybrid',
          document_capture_session_uuid: document_capture_session_uuid,
          failure_to_proof_url: return_to_sp_failure_to_proof_url(step: 'document_capture'),
          doc_auth_selfie_capture: resolved_authn_context_result.biometric_comparison?,
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
          liveness_checking_required: resolved_authn_context_result.biometric_comparison?,
          selfie_check_required: resolved_authn_context_result.biometric_comparison?,
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
