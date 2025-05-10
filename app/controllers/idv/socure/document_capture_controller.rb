# frozen_string_literal: true

module Idv
  module Socure
    class DocumentCaptureController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include DocumentCaptureConcern
      include RenderConditionConcern

      check_or_render_not_found -> { IdentityConfig.store.socure_docv_enabled }

      before_action :confirm_not_rate_limited, except: :update
      before_action -> do
        confirm_not_rate_limited(check_last_submission: true)
      end, only: :update

      before_action :confirm_step_allowed
      before_action -> do
        redirect_to_correct_vendor(Idp::Constants::Vendors::SOCURE, in_hybrid_mobile: false)
      end, only: :show
      before_action :fetch_test_verification_data, only: [:update]

      def show
        analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)
        idv_session.socure_docv_wait_polling_started_at = nil

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer])
          .call('socure_document_capture', :view, true)

        if document_capture_session.socure_docv_capture_app_url.present?
          @url = document_capture_session.socure_docv_capture_app_url
          return
        end

        # document request
        document_request = DocAuth::Socure::Requests::DocumentRequest.new(
          redirect_url: idv_socure_document_capture_update_url,
          language: I18n.locale,
          liveness_checking_required: resolved_authn_context_result.facial_match?,
        )
        timer = JobHelpers::Timer.new
        document_response = timer.time('vendor_request') do
          document_request.fetch
        end

        @url = document_response.dig(:data, :url)

        track_document_request_event(document_request:, document_response:, timer:)

        # placeholder until we get an error page for url not being present
        if @url.nil?
          redirect_to idv_socure_document_capture_errors_url(error_code: :url_not_found)
          return
        end

        document_capture_session.socure_docv_transaction_token = document_response.dig(
          :data,
          :docvTransactionToken,
        )
        document_capture_session.socure_docv_capture_app_url = document_response.dig(
          :data,
          :url,
        )
        document_capture_session.save
      end

      def update
        return if wait_for_result?

        clear_future_steps!
        idv_session.redo_document_capture = nil # done with this redo
        # Not used in standard flow, here for data consistency with hybrid flow.
        document_capture_session.confirm_ocr

        result = handle_stored_result
        # TODO: new analytics event?
        analytics.idv_doc_auth_document_capture_submitted(**result.to_h.merge(analytics_arguments))

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer])
          .call('socure_document_capture', :update, true)

        if result.success?
          redirect_to idv_ssn_url
        else
          redirect_to idv_socure_document_capture_errors_url
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
                idv_session.skip_hybrid_handoff ||
                idv_session.desktop_selfie_test_mode_enabled?)
          },
          undo_step: ->(idv_session:, user:) do
            idv_session.pii_from_doc = nil
            idv_session.socure_docv_wait_polling_started_at = nil
            idv_session.invalidate_in_person_pii_from_user!
            idv_session.doc_auth_vendor = nil
          end,
        )
      end

      private

      def wait_for_result?
        document_capture_session.reload unless document_capture_session.result_id
        return false if document_capture_session.load_result.present?

        # If the stored_result is nil, the job fetching the results has not completed.
        analytics.idv_doc_auth_document_capture_polling_wait_visited(**analytics_arguments)
        if wait_timed_out?
          redirect_to idv_socure_document_capture_errors_url(error_code: :timeout)
        else
          @refresh_interval =
            IdentityConfig.store.doc_auth_socure_wait_polling_refresh_max_seconds
          render 'idv/socure/document_capture/wait'
        end

        true
      end

      def wait_timed_out?
        if idv_session.socure_docv_wait_polling_started_at.nil?
          idv_session.socure_docv_wait_polling_started_at = Time.zone.now.to_s
          return false
        end
        start = DateTime.parse(idv_session.socure_docv_wait_polling_started_at)
        timeout_period =
          IdentityConfig.store.doc_auth_socure_wait_polling_timeout_minutes.minutes || 2.minutes
        start + timeout_period < Time.zone.now
      end

      def analytics_arguments
        {
          flow_path: flow_path,
          step: 'socure_document_capture',
          analytics_id: 'Doc Auth',
          redo_document_capture: idv_session.redo_document_capture,
          skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
          liveness_checking_required: resolved_authn_context_result.facial_match?,
          selfie_check_required: resolved_authn_context_result.facial_match?,
          pii_like_keypaths: [[:pii]],
        }.merge(ab_test_analytics_buckets)
      end
    end
  end
end
