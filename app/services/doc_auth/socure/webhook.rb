# frozen_string_literal: true

# Handles SET events (Security Event Tokens)
module DocAuth
  module Socure
    class Webhook
      attr_reader :payload

      def initialize(payload)
        @payload = payload
      end

      def handle_event
        # validate_payload

        case event_type
        when 'VERIFICATION_COMPLETED'
          verification_completed
        when 'DOCUMENTS_UPLOADED'
          documents_uploaded
        end
      end

      private

      def event
        payload&.dig('event')
      end

      def event_type
        event&.dig('eventType')
      end

      def customer_user_id
        event&.dig('customerUserId')
      end

      def validate_payload
        # socure_webhook_secret_key = IdentityConfig.store.socure_webhook_secret_key
        # raise 'Socure webhook key not configured' if socure_webhook_secret_key.blank?
      end

      def verification_completed
        return unless document_capture_session

        verify_document_data(event.dig('data', 'documentVerification'))
      end

      def documents_uploaded
        return if IdentityConfig.store.socure_verification_level > 1

        if (socure_document_uuid = event.dig('data', 'uuid'))
          uploaded_documents_decision(socure_document_uuid)
        end
      end

      def document_capture_session
        @document_capture_session ||= DocumentCaptureSession.find_by(
          uuid: customer_user_id,
        )
      end

      def webhook_event(event_type)
        webhook_events.find { |t| t.dig('event', 'eventType') == event_type }
      end
    end
  end
end