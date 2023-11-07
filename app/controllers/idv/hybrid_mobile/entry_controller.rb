module Idv
  module HybridMobile
    # Controller responsible for taking a `document-capture-session` UUID and configuring
    # the user's Session to work when they're forwarded on to document capture.
    class EntryController < ApplicationController
      include HybridMobileConcern

      def show
        track_document_capture_session_id_usage

        return handle_invalid_document_capture_session if !validate_document_capture_session_id

        return handle_invalid_document_capture_session if !validate_document_capture_user_id

        redirect_to idv_hybrid_mobile_document_capture_url
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

      def request_id
        params.fetch(:request_id, '')
      end

      def track_document_capture_session_id_usage
        irs_attempts_api_tracker.idv_phone_upload_link_used
      end

      def update_sp_session
        return if sp_session[:issuer] || request_id.blank?
        StoreSpMetadataInSession.new(session:, request_id:).call
      end

      def validate_document_capture_session_id
        if document_capture_session_uuid.blank?
          # If we've already gotten a document capture user id previously, just continue
          # processing and (eventually) redirect the user where they're supposed to be.
          return true if document_capture_user_id
        end

        result = Idv::DocumentCaptureSessionForm.new(document_capture_session_uuid).submit

        event_properties = result.to_h.tap do |properties|
          # See LG-8890 for context
          properties[:doc_capture_user_id?] = session[:doc_capture_user_id].present?
        end

        analytics.track_event 'Doc Auth', event_properties

        if result.success?
          reset_session

          session[:doc_capture_user_id] = result.extra[:for_user_id]
          session[:document_capture_session_uuid] = document_capture_session_uuid

          update_sp_session

          true
        end
      end

      def validate_document_capture_user_id
        !!document_capture_user_id
      end
    end
  end
end
