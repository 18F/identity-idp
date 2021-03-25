module Idv
  module Steps
    class WelcomeStep < DocAuthBaseStep
      def call
        create_document_capture_session(document_capture_session_uuid_key)
      end

      def form_submit
        return no_camera_redirect if params[:no_camera]
        skip_to_capture if params[:skip_upload]

        Idv::ConsentForm.new.submit(consent_form_params)
      end

      def consent_form_params
        params.permit(:ial2_consent_given)
      end

      private

      def skip_to_capture
        # See: Idv::DocAuthController#update_if_skipping_upload
        flow_session[:skip_upload_step] = true
      end

      def no_camera_redirect
        redirect_to idv_doc_auth_errors_no_camera_url
        msg = 'Doc Auth error: Javascript could not detect camera on mobile device.'
        failure(msg)
      end
    end
  end
end
