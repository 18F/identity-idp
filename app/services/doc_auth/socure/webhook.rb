# frozen_string_literal: true

# Handles SET events (Security Event Tokens)
module DocAuth
  module Socure
    class Webhook
      attr_reader :payload, :document_capture_session_uuid
      # validates_presence_of :reference_id
      # validates_presence_of :document_capture_session_uuid
      # validate :validate_payload # agains socure key

      def initialize(payload)
        @payload = payload # webhook_event('VERIFICATION_COMPLETED') ||
        @document_capture_session_uuid = DocumentCaptureSession.first&.uuid # @event['customerUserId']
      end

      def handle_event
        # validate_payload

        event = payload&.dig('event')
        case event&.dig('eventType')
        when 'VERIFICATION_COMPLETED'
          complete_verification(event)
        end
      end

      private

      def validate_payload
        # socure_webhook_secret_key = IdentityConfig.store.socure_webhook_secret_key
        # raise 'Socure webhook key not configured' if socure_webhook_secret_key.blank?
      end

      def complete_verification(event)
        return unless document_capture_session

        doc_auth_response = Responses::Verification.new(event)
        if doc_auth_response.success?
          doc_pii_response = Idv::DocPiiForm.new(
            pii: doc_auth_response.pii_from_doc.to_h,
            attention_with_barcode: doc_auth_response.attention_with_barcode?,
          ).submit
          if doc_pii_response.success?
            document_capture_session.store_result_from_response(doc_auth_response)
            return
          end
        end

        document_capture_session.store_failed_auth_data(
          front_image_fingerprint: nil,
          back_image_fingerprint: nil,
          selfie_image_fingerprint: nil,
          doc_auth_success: doc_auth_response.doc_auth_success?,
          selfie_status: doc_auth_response.selfie_status,
        )
      end

      def document_capture_session
        @document_capture_session ||= DocumentCaptureSession.find_by(
          uuid: @document_capture_session_uuid,
        )
      end

      def webhook_event(event_type)
        # webhook_events.find { |t| t.dig('event', 'eventType') == event_type }
        {}
      end
    end
  end
end