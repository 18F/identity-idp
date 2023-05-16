module Idv
  module Actions
    class RedoDocumentCaptureAction < Idv::Steps::DocAuthBaseStep
      def self.analytics_submitted_event
        :idv_doc_auth_redo_document_capture_submitted
      end

      def call
        flow_session['redo_document_capture'] = true
        if flow_session[:skip_upload_step]
          redirect_to idv_document_capture_url
        else
          mark_step_incomplete(:upload)

          if !IdentityConfig.store.doc_auth_link_sent_controller_enabled
            mark_step_incomplete(:link_sent)
          end
        end
      end
    end
  end
end
