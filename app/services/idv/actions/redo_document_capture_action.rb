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
          redirect_to idv_hybrid_handoff_url
          flow_session[:flow_path] = nil
        end
      end
    end
  end
end
