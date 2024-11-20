# frozen_string_literal: true

module Idv
  module HybridMobile
    module Socure
      class DocumentCaptureController < ApplicationController
        include AvailabilityConcern
        include DocumentCaptureConcern
        include Idv::HybridMobile::HybridMobileConcern
        include RenderConditionConcern

        check_or_render_not_found -> { IdentityConfig.store.socure_docv_enabled }
        before_action :check_valid_document_capture_session, except: [:update]
        before_action -> { redirect_to_correct_vendor(Idp::Constants::Vendors::SOCURE, true) }

        def show
          Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
            call('hybrid_mobile_socure_document_capture', :view, true)

          # document request
          document_request = DocAuth::Socure::Requests::DocumentRequest.new(
            redirect_url: idv_hybrid_mobile_socure_document_capture_update_url,
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
          return if wait_for_result?

          result = handle_stored_result(
            user: document_capture_session.user,
            store_in_session: false,
          )
          # TODO: new analytics event?
          analytics.idv_doc_auth_document_capture_submitted(
            **result.to_h.merge(analytics_arguments),
          )

          if result.success?
            redirect_to idv_hybrid_mobile_capture_complete_url
          else
            redirect_to idv_hybrid_mobile_socure_document_capture_url
          end
        end

        private

        def wait_for_result?
          return false if stored_result.present?

          # If the stored_result is nil, the job fetching the results has not completed.
          analytics.idv_doc_auth_document_capture_polling_wait_visited(**analytics_arguments)
          if wait_timed_out?
            # flash[:error] = I18n.t('errors.doc_auth.polling_timeout')
            # TODO: redirect to try again page LG-14873/14952/15059
            render plain: 'Technical difficulties!!!', status: :ok
          else
            @refresh_interval =
              IdentityConfig.store.doc_auth_socure_wait_polling_refresh_max_seconds
            render 'idv/socure/document_capture/wait'
          end

          true
        end

        def wait_timed_out?
          if session[:socure_docv_wait_polling_started_at].nil?
            session[:socure_docv_wait_polling_started_at] = Time.zone.now.to_s
            return false
          end
          start = DateTime.parse(session[:socure_docv_wait_polling_started_at])
          timeout_period =
            IdentityConfig.store.doc_auth_socure_wait_polling_timeout_minutes.minutes || 2.minutes
          start + timeout_period < Time.zone.now
        end

        def analytics_arguments
          {
            flow_path: 'hybrid',
            step: 'socure_hybrid_document_capture',
            analytics_id: 'Doc Auth',
            redo_document_capture: nil,
            skip_hybrid_handoff: false,
            liveness_checking_required: false,
            selfie_check_required: false,
          }
        end
      end
    end
  end
end
