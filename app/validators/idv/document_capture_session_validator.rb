module Idv
  module DocumentCaptureSessionValidator
    extend ActiveSupport::Concern

    included do
      validates :session_uuid, presence: { message: 'session missing' }
      validate :session_exists, if: :session_uuid_present?
      validate :session_not_expired, if: :session_uuid_present?
    end

    private

    attr_reader :session_uuid

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
