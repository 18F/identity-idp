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
        @payload = ENV['RAILS_ENV'] == 'production' ? payload : webhook_event('VERIFICATION_COMPLETED')
        @document_capture_session_uuid = ENV['RAILS_ENV'] == 'production' ? event['customerUserId'] : DocumentCaptureSession.last&.uuid
      end

      def handle_event
        # validate_payload

        case event_type
        when 'VERIFICATION_COMPLETED'
          complete_verification
        end
      end

      private

      def event
        payload&.dig('event')
      end

      def event_type
        event&.dig('eventType')
      end

      def validate_payload
        # socure_webhook_secret_key = IdentityConfig.store.socure_webhook_secret_key
        # raise 'Socure webhook key not configured' if socure_webhook_secret_key.blank?
      end

      def complete_verification
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
          uuid: document_capture_session_uuid,
        )
      end

      def webhook_event(event_type)
        webhook_events.find { |t| t.dig('event', 'eventType') == event_type }
      end

      def webhook_events
        [{"id"=>"abd83692-a676-4e29-ba6d-33f42b4e5023",
      "origId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
      "eventGroup"=>"DocvNotification",
      "reason"=>"SESSION_COMPLETE",
      "environmentName"=>"Sandbox",
      "event"=>
      {"eventType"=>"SESSION_COMPLETE",
        "referenceId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
        "message"=>"Session Complete",
        "created"=>"2024-06-07T14:50:35.992Z"}},
    {"id"=>"254b5a5d-8465-4545-80fc-f1d0da905bc7",
      "origId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
      "eventGroup"=>"DocvNotification",
      "reason"=>"VERIFICATION_COMPLETED",
      "environmentName"=>"Sandbox",
      "event"=>
      {"eventType"=>"VERIFICATION_COMPLETED",
        "data"=>
        {"documentVerification"=>
          {"reasonCodes"=>["I831", "I836"],
            "documentType"=>{"type"=>"Drivers License", "country"=>"USA", "state"=>"NY"},
            "decision"=>{"name"=>"standard", "value"=>"accept"},
            "documentData"=>
            {"expirationDate"=>"2020-01-01",
              "dob"=>"1980-01-01",
              "fullName"=>"Jane Doe",
              "documentNumber"=>"11223344",
              "firstName"=>"Jane",
              "surName"=>"Doe",
              "address"=>"463 Mertz Motorway, Port Spencer, OH 65036",
              "parsedAddress"=>{"city"=>"Port Spencer", "zip"=>"65036", "state"=>"OH", "country"=>"USA", "physicalAddress"=>"463 Mertz Motorway"},
              "issueDate"=>"2015-01-01"}},
          "referenceId"=>"93412313-cd74-4cec-9ecf-8dc97ac8461a"},
        "referenceId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
        "message"=>"Verification Completed",
        "created"=>"2024-06-07T14:50:35.967Z"}},
    {"id"=>"0a4ff8c5-324c-4a83-8b18-c4ea6f74dfdc",
      "origId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
      "eventGroup"=>"DocvNotification",
      "reason"=>"DOCUMENTS_UPLOADED",
      "environmentName"=>"Sandbox",
      "event"=>
      {"eventType"=>"DOCUMENTS_UPLOADED",
        "data"=>{"uuid"=>"71381646-37bd-4ecf-a934-7144031f04b8", "referenceId"=>"5857f66a-d1ff-4bae-bb96-5bfcb110df11"},
        "referenceId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
        "message"=>"Documents Upload Successful",
        "created"=>"2024-06-07T14:50:35.614Z"}},
    {"id"=>"f938bdbb-6946-4199-9322-44c1468e946b",
      "origId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
      "eventGroup"=>"DocvNotification",
      "reason"=>"DOCUMENT_SELFIE_UPLOADED",
      "environmentName"=>"Sandbox",
      "event"=>
      {"eventType"=>"DOCUMENT_SELFIE_UPLOADED",
        "referenceId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
        "message"=>"Document Selfie Uploaded",
        "created"=>"2024-06-07T14:50:35.604Z"}},
    {"id"=>"b381c6fe-9eaa-4e0b-84ac-e7ce9bc2de32",
      "origId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
      "eventGroup"=>"DocvNotification",
      "reason"=>"DOCUMENT_BACK_UPLOADED",
      "environmentName"=>"Sandbox",
      "event"=>
      {"eventType"=>"DOCUMENT_BACK_UPLOADED",
        "referenceId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
        "message"=>"Document Back Uploaded",
        "created"=>"2024-06-07T14:50:20.911Z"}},
    {"id"=>"22c7d280-a649-4941-b4b4-6f6ff8ced841",
      "origId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
      "eventGroup"=>"DocvNotification",
      "reason"=>"DOCUMENT_FRONT_UPLOADED",
      "environmentName"=>"Sandbox",
      "event"=>
      {"eventType"=>"DOCUMENT_FRONT_UPLOADED",
        "referenceId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
        "message"=>"Document Front Uploaded",
        "created"=>"2024-06-07T14:49:57.321Z"}},
    {"id"=>"e4f22335-8254-4da3-a1c7-0024b4e36eac",
      "origId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
      "eventGroup"=>"DocvNotification",
      "reason"=>"APP_OPENED",
      "environmentName"=>"Sandbox",
      "event"=>
      {"eventType"=>"APP_OPENED",
        "referenceId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
        "message"=>"Capture App Opened",
        "created"=>"2024-06-07T14:49:29.252Z"}},
    {"id"=>"87a8fc7d-178b-4e55-b403-626d92c5eba6",
      "origId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
      "eventGroup"=>"DocvNotification",
      "reason"=>"WAITING_FOR_USER_TO_REDIRECT",
      "environmentName"=>"Sandbox",
      "event"=>
      {"eventType"=>"WAITING_FOR_USER_TO_REDIRECT",
        "referenceId"=>"1aab154e-a23a-4c65-baa7-75fe220236f6",
        "message"=>"Process Initiated",
        "created"=>"2024-06-07T14:42:56.974Z"}},
    {"id"=>"d8547f07-144a-4772-9a51-83a74e71e08e",
      "origId"=>"246f1800-445c-4e5c-98d8-03143dd167a0",
      "eventGroup"=>"DocvNotification",
      "reason"=>"WAITING_FOR_USER_TO_REDIRECT",
      "environmentName"=>"Sandbox",
      "event"=>
      {"eventType"=>"WAITING_FOR_USER_TO_REDIRECT",
        "referenceId"=>"246f1800-445c-4e5c-98d8-03143dd167a0",
        "message"=>"Process Initiated",
        "created"=>"2024-06-07T14:42:52.396Z"}},
    {"id"=>"3827da7b-4f4a-4a50-9d1d-667f12c4f330",
      "origId"=>"8d552f18-a20a-4af5-bbb0-0a2751a16a7a",
      "eventGroup"=>"DocvNotification",
      "reason"=>"WAITING_FOR_USER_TO_REDIRECT",
      "environmentName"=>"Sandbox",
      "event"=>
      {"eventType"=>"WAITING_FOR_USER_TO_REDIRECT",
        "referenceId"=>"8d552f18-a20a-4af5-bbb0-0a2751a16a7a",
        "message"=>"Process Initiated",
        "created"=>"2024-06-07T14:42:36.389Z"}}]
      end
    end
  end
end