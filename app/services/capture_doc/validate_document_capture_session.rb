module CaptureDoc
  class ValidateDocumentCaptureSession
    include ActiveModel::Model
    include Idv::DocumentCaptureSessionValidator

    def initialize(session_uuid)
      @session_uuid = session_uuid
    end

    def call
      @success = valid?

      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    attr_reader :success

    def extra_analytics_attributes
      {
        for_user_id: document_capture_session&.user_id,
        user_id: 'anonymous-uuid',
        event: 'Document capture session validation',
      }
    end
  end
end
