module Idv
  module Steps
    class AgreementStep < DocAuthBaseStep
      STEP_INDICATOR_STEP = :getting_started

      def self.analytics_visited_event
        :idv_doc_auth_agreement_visited
      end

      def self.analytics_submitted_event
        :idv_doc_auth_agreement_submitted
      end

      def call
        return if !IdentityConfig.store.doc_auth_hybrid_handoff_controller_enabled

        if flow_session[:skip_upload_step]
          redirect_to idv_document_capture_url
        else
          redirect_to idv_hybrid_handoff_url
        end
      end

      def form_submit
        skip_to_capture if params[:skip_upload]

        Idv::ConsentForm.new.submit(consent_form_params)
      end

      def skip_to_capture
        # See: Idv::DocAuthController#update_if_skipping_upload
        flow_session[:skip_upload_step] = true
        if IdentityConfig.store.doc_auth_hybrid_handoff_controller_enabled
          flow_session[:flow_path] = 'standard'
        end
      end

      def consent_form_params
        params.require(:doc_auth).permit(:ial2_consent_given)
      end
    end
  end
end
