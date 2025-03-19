# frozen_string_literal: true

module Idv
  module HybridMobile
    module HybridMobileConcern
      extend ActiveSupport::Concern

      include AcuantConcern
      include Idv::AbTestAnalyticsConcern

      def analytics_user
        current_or_hybrid_user || AnonymousUser.new
      end

      def current_or_hybrid_user
        return User.find_by(id: session[:doc_capture_user_id]) if !current_user && hybrid_user?

        current_user
      end

      def hybrid_user?
        session[:doc_capture_user_id].present?
      end

      def check_valid_document_capture_session
        if !document_capture_user
          # The user has not "logged in" to document capture via the EntryController
          return handle_invalid_document_capture_session
        end

        if !document_capture_session
          # The user has not visited the EntryController with a valid document capture session UUID
          return handle_invalid_document_capture_session
        end

        return handle_invalid_document_capture_session if document_capture_session.expired?
      end

      def correct_vendor_url
        case document_capture_session.doc_auth_vendor
        when Idp::Constants::Vendors::SOCURE, Idp::Constants::Vendors::SOCURE_MOCK
          idv_hybrid_mobile_socure_document_capture_url
        when Idp::Constants::Vendors::MOCK, Idp::Constants::Vendors::LEXIS_NEXIS
          idv_hybrid_mobile_document_capture_url
        end
      end

      def document_capture_session
        return @document_capture_session if defined?(@document_capture_session)
        @document_capture_session =
          DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
      end

      def document_capture_session_uuid
        session[:document_capture_session_uuid]
      end

      def document_capture_user
        return @document_capture_user if defined?(@document_capture_user)
        @document_capture_user = User.find_by(id: session[:doc_capture_user_id])
      end

      def handle_invalid_document_capture_session
        # it is critical to remove all session data to avoid authenticating and
        # resuming a partial session
        sign_out
        flash[:error] = t('errors.capture_doc.invalid_link')
        redirect_to root_url
      end
    end
  end
end
