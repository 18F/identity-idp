module Db
  module DocumentCaptureSession
    class ReadVerifyDocStatus
      def self.call(uuid)
        document_capture_session = ::DocumentCaptureSession.find_by(uuid: uuid)
        document_capture_session&.verify_doc_status
      end
    end
  end
end
