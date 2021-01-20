module Idv
  module Steps
    class RecoverStep < DocAuthBaseStep
      def call
        create_document_capture_session(document_capture_session_uuid_key)
      end
    end
  end
end
