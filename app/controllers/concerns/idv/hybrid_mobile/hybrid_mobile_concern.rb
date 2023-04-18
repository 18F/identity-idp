module Idv
  module HybridMobile
    module HybridMobileConcern
      extend ActiveSupport::Concern

      included do
        before_action :render_404_if_hybrid_mobile_controllers_disabled
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

      def document_capture_session
        @document_capture_session ||=
          DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
      end

      def document_capture_session_uuid
        session[:document_capture_session_uuid]
        # TODO: Do we need to fall back to searching in flow_session?
      end

      def document_capture_user
        @document_capture_user ||= begin
          User.find(session[:doc_capture_user_id])
        rescue ActiveRecord::RecordNotFound
          nil
        end
      end

      def flow_session
        session['idv/doc_auth'] ||= {}
      end

      def handle_invalid_document_capture_session
        flash[:error] = t('errors.capture_doc.invalid_link')
        redirect_to root_url
      end

      def idv_session
        @idv_session ||= Idv::Session.new(
          user_session: session,
          current_user: document_capture_user,
          service_provider: current_sp,
        )
      end

      def render_404_if_hybrid_mobile_controllers_disabled
        render_not_found unless IdentityConfig.store.doc_auth_hybrid_mobile_controllers_enabled
      end
    end
  end
end
