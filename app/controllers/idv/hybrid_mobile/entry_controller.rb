module Idv
  module HybridMobile
    # Controller responsible for taking a `document-capture-session` UUID and configuring
    # the user's Session to work when they're forwarded on to document capture.
    class EntryController < ApplicationController
      before_action :render_404_if_hybrid_mobile_controllers_disabled
      before_action :track_document_capture_session_id_usage
      before_action :validate_document_capture_session_id
      before_action :validate_document_capture_user_id

      def show
        redirect_to idv_hybrid_mobile_capture_doc_url
      end

      private

      # This is the UUID present in the link sent to the user via SMS.
      # It refers to a DocumentCaptureSession instance in the DB.
      def document_capture_session_uuid
        params['document-capture-session']
      end

      # This is the effective user for whom we are uploading documents.
      def document_capture_user_id
        session[:doc_capture_user_id]
      end

      def handle_invalid_session
        flash[:error] = t('errors.capture_doc.invalid_link')
        redirect_to root_url
      end

      def render_404_if_hybrid_mobile_controllers_disabled
        render_not_found unless IdentityConfig.store.doc_auth_hybrid_mobile_controllers_enabled
      end

      def request_id
        params.fetch(:request_id, '')
      end

      def track_document_capture_session_id_usage
        irs_attempts_api_tracker.idv_phone_upload_link_used
      end

      def update_sp_session
        return if sp_session[:issuer] || request_id.blank?
        StoreSpMetadataInSession.new(session: session, request_id: request_id).call
      end

      def validate_document_capture_session_id
        if document_capture_session_uuid.blank?
          # If we've already gotten a document capture user id previously, just continue
          # processing and (eventually) redirect the user where they're supposed to be.
          return if document_capture_user_id
        end

        result = Idv::DocumentCaptureSessionForm.new(document_capture_session_uuid).submit

        if result.success?
          reset_session

          session[:doc_capture_user_id] = result.extra[:for_user_id]
          session[:document_capture_session_uuid] = document_capture_session_uuid

          update_sp_session
        else
          handle_invalid_session
        end

        #         return if session[:doc_capture_user_id] &&
        #         token.blank? &&
        #         document_capture_session_uuid.blank?

        # result = Idv::DocumentCaptureSessionForm.new(document_capture_session_uuid).submit
        # to_log = result.to_h
        # # Log value used to determine session type ("hybrid flow" or not)
        # to_log[:doc_capture_user_id?] = session[:doc_capture_user_id].present?

        # analytics.track_event(FLOW_STATE_MACHINE_SETTINGS[:analytics_id], to_log)
        # process_result(result)
      end

      def validate_document_capture_user_id
        handle_invalid_session unless document_capture_user_id
      end
    end
  end
end
