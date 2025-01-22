# frozen_string_literal: true

class SocureDocvResultsJob < ApplicationJob
  queue_as :high_socure_docv

  attr_reader :document_capture_session_uuid, :async, :docv_transaction_token_override

  # @param [String] document_capture_session_uuid
  def perform(document_capture_session_uuid:, async: true, docv_transaction_token_override: nil)
    @document_capture_session_uuid = document_capture_session_uuid
    @async = async
    @docv_transaction_token_override = docv_transaction_token_override

    raise "DocumentCaptureSession not found: #{document_capture_session_uuid}" unless
      document_capture_session

    timer = JobHelpers::Timer.new
    client_response = timer.time('vendor_request') do
      socure_document_verification_result
    end

    document_response_validator = Idv::DocumentResponseValidator.new(
      form_response: Idv::DocAuthFormResponse.new(
        success: socure_document_verification_result.success?,
        errors: socure_document_verification_result.errors,
        extra: {},
      ),
    )
    document_response_validator.client_response = client_response
    document_response_validator.validate_pii_from_doc(
      document_capture_session:,
      extra_attributes: {
        remaining_submit_attempts: rate_limiter&.remaining_count,
        flow_path: nil,
        liveness_checking_required: client_response.biometric_comparison_required,
        submit_attempts: rate_limiter&.attempts,
      },
      analytics:,
    )

    document_response_validator.response.extra[:failed_image_fingerprints] =
      document_response_validator.store_failed_images(
        document_capture_session,
        {},
      )

    log_verification_request(
      docv_result_response: client_response,
      vendor_request_time_in_ms: timer.results['vendor_request'],
    )
  end

  private

  def analytics
    @analytics ||= Analytics.new(
      user: document_capture_session.user,
      request: nil,
      session: {},
      sp: document_capture_session.issuer,
    )
  end

  def log_verification_request(docv_result_response:, vendor_request_time_in_ms:)
    analytics.idv_socure_verification_data_requested(
      **docv_result_response.to_h.merge(
        docv_transaction_token: document_capture_session.socure_docv_transaction_token,
        submit_attempts: rate_limiter&.attempts,
        remaining_submit_attempts: rate_limiter&.remaining_count,
        vendor_request_time_in_ms:,
        async:,
        pii_like_keypaths: [[:pii]],
      ).except(:attention_with_barcode, :selfie_live, :selfie_quality_good,
               :selfie_status, :failed_image_fingerprints),
    )
  end

  def socure_document_verification_result
    @socure_document_verification_result ||=
      DocAuth::Socure::Requests::DocvResultRequest.new(
        document_capture_session_uuid:,
        docv_transaction_token_override:,
      ).fetch
  end

  def document_capture_session
    @document_capture_session ||=
      DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
  end

  def rate_limiter
    @rate_limiter ||= RateLimiter.new(
      user: document_capture_session.user,
      rate_limit_type: :idv_doc_auth,
    )
  end
end
