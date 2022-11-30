module Idv
  class ValidateDocumentCaptureSessionForm
    include ActiveModel::Model

    validates :session_uuid, presence: { message: 'session missing' }
    validate :session_exists, if: :session_uuid_present?
    validate :session_not_expired, if: :session_uuid_present?

    def initialize(session_uuid)
      @session_uuid = session_uuid
    end

    def submit
      @success = valid?

      FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
    end

    private

    attr_reader :success, :session_uuid

    def extra_analytics_attributes
      {
        for_user_id: document_capture_session&.user_id,
        user_id: 'anonymous-uuid',
        event: 'Document capture session validation',
        ial2_strict: document_capture_session&.ial2_strict?,
        sp_issuer: document_capture_session&.issuer,
      }
    end

    def session_exists
      return if document_capture_session
      errors.add(:session_uuid, 'invalid session', type: :doc_capture_sessions)
    end

    def session_not_expired
      return unless document_capture_session&.expired?
      errors.add(:session_uuid, 'session expired', type: :doc_capture_sessions)
    end

    def session_uuid_present?
      session_uuid.present?
    end

    def document_capture_session
      @document_capture_session ||= DocumentCaptureSession.find_by(uuid: session_uuid)
    end
  end
end
