module Idv
  module Steps
    class WelcomeStep < DocAuthBaseStep
      def call
        return no_camera_redirect if params[:no_camera]
        create_document_capture_session(document_capture_session_uuid_key)
      end

      private

      def no_camera_redirect
        redirect_to idv_doc_auth_errors_no_camera_url
        msg = 'Doc Auth error: Javascript could not detect camera on mobile device.'
        failure(msg)
      end
    end
  end
end
