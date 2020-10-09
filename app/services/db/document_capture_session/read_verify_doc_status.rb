module Db
  module DocumentCaptureSession
    class ReadVerifyDocStatus
      IN_PROGRESS = 'in_progress'.freeze

      def self.call(uuid)
        doc_capture_session = ::DocumentCaptureSession.find_by(uuid: uuid)
        return unless doc_capture_session && doc_capture_session.verify_doc_submitted_at.present?
        doc_capture_session.verify_doc_status || IN_PROGRESS
      end
    end
  end
end
