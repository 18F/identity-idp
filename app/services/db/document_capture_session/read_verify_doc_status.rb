module Db
  module DocumentCaptureSession
    class ReadVerifyDocStatus
      def self.call(uuid)
        doc_capture_session = ::DocumentCaptureSession.find_by(uuid: uuid)
        return unless doc_capture_session && doc_capture_session.verify_doc_submitted_at.present?
        doc_capture_session.verify_doc_status || :in_progress
      end
    end
  end
end
