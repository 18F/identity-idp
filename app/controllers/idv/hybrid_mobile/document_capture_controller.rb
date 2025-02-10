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
      before_action -> do
        redirect_to_correct_vendor(Idp::Constants::Vendors::LEXIS_NEXIS, in_hybrid_mobile: true)
      end, only: [:show], unless: -> { allow_direct_ipp? }

      def show
        analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer])
          .call('document_capture', :view, true)

        render :show, locals: extra_view_variables
      end

      def update
        document_capture_session.confirm_ocr
        result = handle_stored_result(
          user: document_capture_user,
          store_in_session: false,
        )

        analytics.idv_doc_auth_document_capture_submitted(**result.to_h.merge(analytics_arguments))

        Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer])
          .call('document_capture', :update, true)

        # rate limiting redirect is in ImageUploadResponsePresenter
        if result.success?
          redirect_to idv_hybrid_mobile_capture_complete_url
        else
          redirect_to idv_hybrid_mobile_document_capture_url
        end
      end

      # Given that the start of the IPP flow is in the TrueID doc_auth React app,
      # we need a generic, direct way to start the IPP flow
      def direct_in_person
        attributes = {
          remaining_submit_attempts: rate_limiter.remaining_count,
          flow_path: :hybrid,
        }.merge(ab_test_analytics_buckets)
        analytics.idv_in_person_direct_start(**attributes)

        redirect_to idv_hybrid_mobile_document_capture_url(step: :idv_doc_auth)
      end

      def extra_view_variables
        {
          flow_path: 'hybrid',
          mock_client: doc_auth_vendor == 'mock',
          document_capture_session_uuid: document_capture_session_uuid,
          failure_to_proof_url: return_to_sp_failure_to_proof_url(step: 'document_capture'),
          doc_auth_selfie_capture: resolved_authn_context_result.facial_match?,
          skip_doc_auth_from_socure: @skip_doc_auth_from_socure,
          socure_errors_timeout_url: idv_hybrid_mobile_socure_errors_timeout_url,
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

      def allow_direct_ipp?
        return false if params[:step].blank?
        return false if params[:action].to_s != 'show' && params[:action] != 'direct_in_person'
        # Only allow direct access to document capture if IPP available
        return false unless IdentityConfig.store.in_person_doc_auth_button_enabled &&
                            Idv::InPersonConfig.enabled_for_issuer?(sp_session[:issuer])

        # allow
        @previous_step_url = params[:step] == 'hybrid_handoff' ? idv_hybrid_handoff_path : nil
        @skip_doc_auth_from_socure = true
        true
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

      def rate_limiter
        RateLimiter.new(user: document_capture_user, rate_limit_type: :idv_doc_auth)
      end
    end
  end
end
