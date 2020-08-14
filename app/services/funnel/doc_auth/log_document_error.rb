module Funnel
  module DocAuth
    class LogDocumentError
      def self.call(user_id, document_error)
        doc_auth_log = DocAuthLog.find_by(user_id: user_id)
        return if doc_auth_log.nil?
        doc_auth_log.last_document_error = document_error
        doc_auth_log.save
      end
    end
  end
end
