module Idv
  module Actions
    class RedoDocumentCaptureAction < Idv::Steps::DocAuthBaseStep
      def self.analytics_submitted_event
        :idv_doc_auth_redo_document_capture_submitted
      end

      def call
        mark_step_incomplete(:document_capture)
        unless flow_session[:skip_upload_step]
          mark_step_incomplete(:email_sent)
          mark_step_incomplete(:link_sent)
          mark_step_incomplete(:send_link)
          mark_step_incomplete(:upload)
        end
      end
    end
  end
end
