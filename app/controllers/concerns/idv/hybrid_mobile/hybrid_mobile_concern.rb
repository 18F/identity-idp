module Idv
  module HybridMobile
    module HybridMobileConcern
      extend ActiveSupport::Concern

      included do
        before_action :render_404_if_hybrid_mobile_controllers_disabled
      end

      def check_valid_document_capture_session
        return redirect_to root_url if !document_capture_user
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

      def render_404_if_hybrid_mobile_controllers_disabled
        render_not_found unless IdentityConfig.store.doc_auth_hybrid_mobile_controllers_enabled
      end
    end
  end
end
