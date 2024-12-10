# frozen_string_literal: true

module Idv
  module HybridMobile
    module Socure
      class DocumentCaptureController < ApplicationController
        include AvailabilityConcern
        include DocumentCaptureConcern
        include Idv::HybridMobile::HybridMobileConcern
        include RenderConditionConcern
        include SocureErrorsConcern

        check_or_render_not_found -> { IdentityConfig.store.socure_docv_enabled }
        before_action :check_valid_document_capture_session, except: [:update]
        before_action -> { redirect_to_correct_vendor(Idp::Constants::Vendors::SOCURE, true) },
                      only: :show
        before_action :fetch_test_verification_data, only: [:update]

        def show
          Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
            call('hybrid_mobile_socure_document_capture', :view, true)

          # document request
          document_request = DocAuth::Socure::Requests::DocumentRequest.new(
            redirect_url: idv_hybrid_mobile_socure_document_capture_update_url,
            language: I18n.locale,
          )
          timer = JobHelpers::Timer.new
          document_response = timer.time('vendor_request') do
            document_request.fetch
          end

          @url = document_response.dig(:data, :url)

          track_document_request_event(document_request:, document_response:, timer:)

          # placeholder until we get an error page for url not being present
          if @url.nil?
            redirect_to idv_hybrid_mobile_socure_document_capture_errors_url
            return
          end

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
            redirect_to idv_hybrid_mobile_socure_document_capture_errors_url
          end
        end

        private

        def socure_errors_presenter(result)
          SocureErrorPresenter.new(
            error_code: error_code_for(result),
            remaining_attempts:,
            sp_name: decorated_sp_session&.sp_name || APP_NAME,
            hybrid_mobile: true,
          )
        end

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
            step: 'socure_document_capture',
            analytics_id: 'Doc Auth',
            liveness_checking_required: false,
            selfie_check_required: false,
          }
        end
      end
    end
  end
end
