module Api
  module Verify
    class DocumentCaptureErrorsDeleteForm
      include ActiveModel::Model

      validates_presence_of :document_capture_session_uuid
      validate :validate_document_capture_session

      attr_reader :document_capture_session_uuid

      def initialize(document_capture_session_uuid: nil)
        @document_capture_session_uuid = document_capture_session_uuid
      end

      def submit
        result = FormResponse.new(
          success: valid?,
          errors: errors,
        )

        [result, document_capture_session]
      end

      private

      def validate_document_capture_session
        return if document_capture_session || !document_capture_session_uuid
        errors.add(
          :document_capture_session_uuid,
          'Invalid document capture session',
          type: :invalid_document_capture_session,
        )
      end

      def document_capture_session
        return @document_capture_session if defined?(@document_capture_session)
        @document_capture_session = DocumentCaptureSession.find_by(
          uuid: document_capture_session_uuid,
        )
      end
    end
  end
end
