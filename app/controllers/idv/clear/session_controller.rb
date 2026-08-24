# frozen_string_literal: true

module Idv
  module Clear
    class SessionController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include RenderConditionConcern

      # check_or_render_not_found -> { clear_enabled? }

      # before_action :confirm_not_rate_limited, except: :update
      # before_action -> do
      #   confirm_not_rate_limited(check_last_submission: true)
      # end, only: :update

      # before_action :confirm_step_allowed
      # before_action :update_doc_auth_vendor, only: :show
      # before_action -> do
      #   redirect_to_correct_vendor(Idp::Constants::Vendors::CLEAR, in_hybrid_mobile: false)
      # end, only: :show

      def show
        timer = JobHelpers::Timer.new
        clear_session = timer.time('vendor_request') do
          clear_session_request = Proofing::Clear::Requests::SessionRequest.new
          clear_session_request.fetch
        end

        if clear_session.success?
          token = clear_session.extra[:token]

          document_capture_session.update!(doc_auth_vendor: Idp::Constants::Vendors::CLEAR)

          @clear_endpoint = UriService.add_params(
            [IdentityConfig.store.idv_clear_api_base_url, 'verify'].join('/'),
            { token: },
          )
        else
          redirect_to idv_hybrid_handoff_path
        end
      end

      def update
        # todo: fetch clear status
        # if successful, redirec to password page
        # idv_session.doc_auth_vendor = document_capture_session.doc_auth_vendor
        # if fail, redirect to hybrid handoff (temporary)
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :clear_session,
          controller: self,
          next_steps: [:enter_password],
          preconditions: ->(idv_session:, user:) {
            idv_session.flow_path == 'standard' &&
            idv_session.clear_enabled
          },
          undo_step: ->(idv_session:, user:) do
            idv_session.pii_from_doc = nil
            idv_session.doc_auth_vendor = nil
            idv_session.source_check_vendor = nil
          end,
        )
      end

      private

      def wait_for_result?
        document_capture_session.reload unless document_capture_session.result_id
        return false if document_capture_session.load_result.present?

        # If the stored_result is nil, the job fetching the results has not completed.
        analytics.idv_doc_auth_document_capture_polling_wait_visited(**analytics_arguments)

        if document_capture_session.socure_docv_transaction_token.blank?
          redirect_to idv_socure_document_capture_errors_url(
            error_code: :invalid_transaction_token,
            transaction_token: :MISSING_TRANSACTION_TOKEN,
          )
          return true
        end

        if wait_timed_out?
          analytics.idv_socure_verification_webhook_missing(
            docv_transaction_token: document_capture_session.socure_docv_transaction_token,
          )

          fetch_synchronous_docv_result

          document_capture_session.reload
          return false if document_capture_session.load_result.present?

          redirect_to idv_socure_document_capture_errors_url(
            error_code: :timeout,
            transaction_token: document_capture_session.socure_docv_transaction_token,
          )
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
          step: 'clear_session',
          skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
          pii_like_keypaths: [[:pii]],
        }.merge(ab_test_analytics_buckets)
      end

      def clear_session
        @clear_session ||= begin
          clear_session_request = Proofing::Clear::Requests::SessionRequest.new
          clear_session_request.fetch
        end
      end
    end
  end
end
