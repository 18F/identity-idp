module Idv
  class CaptureDocController < ApplicationController
    # rubocop:disable Rails/LexicallyScopedActionFilter
    # index comes from the flow_state_matchine.rb
    before_action :track_index_loads, only: [:index]
    # rubocop:enable Rails/LexicallyScopedActionFilter
    before_action :ensure_user_id_in_session

    include Flow::FlowStateMachine
    include Idv::DocumentCaptureConcern

    before_action :override_document_capture_step_csp

    FLOW_STATE_MACHINE_SETTINGS = {
      step_url: :idv_capture_doc_step_url,
      final_url: :root_url,
      flow: Idv::Flows::CaptureDocFlow,
      analytics_id: 'Doc Auth',
    }.freeze

    def return_to_sp
      redirect_to return_to_sp_failure_to_proof_url(step: next_step, location: params[:location])
    end

    private

    def track_index_loads
      irs_attempts_api_tracker.idv_phone_upload_link_used
    end

    def ensure_user_id_in_session
      return if session[:doc_capture_user_id] &&
                token.blank? &&
                document_capture_session_uuid.blank?

      result = CaptureDoc::ValidateDocumentCaptureSession.new(document_capture_session_uuid).call

      analytics.track_event(FLOW_STATE_MACHINE_SETTINGS[:analytics_id], result.to_h)
      process_result(result)
    end

    def process_result(result)
      if result.success?
        reset_session
        session[:doc_capture_user_id] = result.extra[:for_user_id]
        session[:document_capture_session_uuid] = document_capture_session_uuid
        update_sp_session_with_result(result)
      else
        flash[:error] = t('errors.capture_doc.invalid_link')
        redirect_to root_url
      end
    end

    def update_sp_session_with_result(_result)
      return if sp_session[:issuer] || request_id.blank?
      StoreSpMetadataInSession.new(session: session, request_id: request_id).call
    end

    def request_id
      params.fetch(:request_id, '')
    end

    def token
      params[:token]
    end

    def document_capture_session_uuid
      params['document-capture-session']
    end
  end
end
