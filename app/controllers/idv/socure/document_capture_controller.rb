# frozen_string_literal: true

module Idv
  module Socure
    class DocumentCaptureController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include DocumentCaptureConcern
      include RenderConditionConcern

      check_or_render_not_found -> { IdentityConfig.store.socure_enabled }
      before_action :confirm_not_rate_limited
      before_action :confirm_step_allowed
      before_action -> { redirect_to_correct_vendor(Idp::Constants::Vendors::SOCURE, false) }

      # reconsider and maybe remove these when implementing the real
      # update handler
      skip_before_action :redirect_unless_idv_session_user, only: [:update]
      skip_before_action :confirm_two_factor_authenticated, only: [:update]
      skip_before_action :confirm_idv_needed, only: [:update]
      skip_before_action :confirm_not_rate_limited, only: [:update]
      skip_before_action :confirm_step_allowed, only: [:update]

      def show
        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('socure_document_capture', :view, true)

        # document request
        document_request = DocAuth::Socure::Requests::DocumentRequest.new(
          redirect_url: idv_socure_document_capture_update_url,
          language: I18n.locale,
        )

        document_response = document_request.fetch

        @document_request = document_request
        @document_response = document_response
        @url = document_response.dig(:data, :url)

        # placeholder until we get an error page for url not being present
        return redirect_to idv_unavailable_url if @url.nil?

        document_capture_session = DocumentCaptureSession.find_by(
          uuid: document_capture_session_uuid,
        )

        document_capture_session.socure_docv_transaction_token = document_response.dig(
          :data,
          :docvTransactionToken,
        )
        document_capture_session.socure_docv_capture_app_url = document_response.dig(
          :data,
          :url,
        )
        document_capture_session.save

        # useful for analytics
        @msg = document_response[:msg]
        @reference_id = document_response[:referenceId]
      end

      def update
        clear_future_steps!
        idv_session.redo_document_capture = nil # done with this redo
        # Not used in standard flow, here for data consistency with hybrid flow.
        document_capture_session.confirm_ocr

        # If the stored_result is nil, the job fetching the results has not completed.
        if stored_result.nil?
          analytics.idv_doc_auth_document_capture_polling_wait_visited(**analytics_arguments)
          render 'idv/socure/document_capture/wait'
          return
        end

        result = handle_stored_result
        # TODO: new analytics event?
        analytics.idv_doc_auth_document_capture_submitted(**result.to_h.merge(analytics_arguments))

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('socure_document_capture', :update, true)

        if result.success?
          redirect_to idv_ssn_url
        else
          redirect_to idv_socure_document_capture_url
        end
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :socure_document_capture,
          controller: self,
          next_steps: [:ssn, :ipp_ssn],
          preconditions: ->(idv_session:, user:) {
            idv_session.flow_path == 'standard' && (
              # mobile
              idv_session.skip_doc_auth_from_handoff ||
              idv_session.skip_hybrid_handoff ||
              idv_session.skip_doc_auth ||
              idv_session.skip_doc_auth_from_how_to_verify ||
              !idv_session.selfie_check_required ||
              idv_session.desktop_selfie_test_mode_enabled?)
          },
          undo_step: ->(idv_session:, user:) do
            idv_session.pii_from_doc = nil
            idv_session.invalidate_in_person_pii_from_user!
          end,
        )
      end

      private

      def analytics_arguments
        {
          flow_path: flow_path,
          step: 'socure_document_capture',
          analytics_id: 'Doc Auth',
          redo_document_capture: idv_session.redo_document_capture,
          skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
          liveness_checking_required: resolved_authn_context_result.facial_match?,
          selfie_check_required: resolved_authn_context_result.facial_match?,
        }.merge(ab_test_analytics_buckets)
      end
    end
  end
end
