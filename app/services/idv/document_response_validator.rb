# frozen_string_literal: true

module Idv
  class DocumentResponseValidator
    attr_reader :form_response, :client_response, :doc_pii_response

    def initialize(form_response:, client_response:)
      @form_response = form_response
      @client_response = client_response
      @doc_pii_response = nil
    end

    def response
      # image validation failed
      return form_response if !form_response.success?

      # doc_pii validation failed
      return doc_pii_response if doc_pii_response.present? && !doc_pii_response.success?

      client_response
    end

    def validate_pii_from_doc(document_capture_session:, extra_attributes:, analytics:)
      return unless client_response.success?

      pii_validator = Idv::PiiValidator.new(
        client_response,
        extra_attributes,
        analytics,
      )

      if pii_validator.success?
        document_capture_session.store_result_from_response(client_response)
      end

      @doc_pii_response = pii_validator.doc_auth_form_response
    end

    ##
    # Store failed image fingerprints in document_capture_session_result
    # when client_response is not successful and not a network error
    # ( http status except handled status 438, 439, 440 ) or doc_pii_response is not successful.
    # @param [DocumentCaptureSession] document_capture_session
    # @param [Hash] extra_attributes
    # @return [Object] latest failed fingerprints
    def store_failed_images(document_capture_session, extra_attributes)
      unless image_resubmission_check?
        return {
          front: [],
          back: [],
          selfie: [],
        }
      end

      # doc auth failed due to non network error or doc_pii is not valid
      if client_response && !client_response.success? && !client_response.network_error?
        errors_hash = client_response.errors&.to_h || {}
        failed_front_fingerprint = nil
        failed_back_fingerprint = nil
        if errors_hash[:front] || errors_hash[:back]
          if errors_hash[:front]
            failed_front_fingerprint = extra_attributes[:front_image_fingerprint]
          end
          if errors_hash[:back]
            failed_back_fingerprint = extra_attributes[:back_image_fingerprint]
          end
        elsif !client_response.doc_auth_success?
          failed_front_fingerprint = extra_attributes[:front_image_fingerprint]
          failed_back_fingerprint = extra_attributes[:back_image_fingerprint]
        end

        document_capture_session.store_failed_auth_data(
          front_image_fingerprint: failed_front_fingerprint,
          back_image_fingerprint: failed_back_fingerprint,
          selfie_image_fingerprint: extra_attributes[:selfie_image_fingerprint],
          doc_auth_success: client_response.doc_auth_success?,
          selfie_status: client_response.selfie_status,
        )

      elsif doc_pii_response && !doc_pii_response.success?
        document_capture_session.store_failed_auth_data(
          front_image_fingerprint: extra_attributes[:front_image_fingerprint],
          back_image_fingerprint: extra_attributes[:back_image_fingerprint],
          selfie_image_fingerprint: extra_attributes[:selfie_image_fingerprint],
          doc_auth_success: client_response.doc_auth_success?,
          selfie_status: client_response.selfie_status,
        )
      end

      # retrieve updated data from session
      captured_result = document_capture_session&.load_result
      {
        front: captured_result&.failed_front_image_fingerprints || [],
        back: captured_result&.failed_back_image_fingerprints || [],
        selfie: captured_result&.failed_selfie_image_fingerprints || [],
      }
    end

    private

    def image_resubmission_check?
      IdentityConfig.store.doc_auth_check_failed_image_resubmission_enabled
    end
  end
end
