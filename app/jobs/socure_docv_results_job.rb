# frozen_string_literal: true

class SocureDocvResultsJob < ApplicationJob
  queue_as :high_socure_docv

  attr_reader :document_capture_session_uuid, :async

  # @param [String] document_capture_session_uuid
  def perform(document_capture_session_uuid:, async: true)
    @document_capture_session_uuid = document_capture_session_uuid
    @async = async

    raise "DocumentCaptureSession not found: #{document_capture_session_uuid}" unless
      document_capture_session

    timer = JobHelpers::Timer.new
    response = timer.time('vendor_request') do
      socure_document_verification_result
    end
    log_verification_request(
      docv_result_response: response,
      vendor_request_time_in_ms: timer.results['vendor_request'],
    )
    document_capture_session.store_result_from_response(response)
  end

  private

  def analytics
    @analytics ||= Analytics.new(
      user: document_capture_session.user,
      service_provider_issuer: document_capture_session.issuer,
    )
  end

  def log_verification_request(docv_result_response:, vendor_request_time_in_ms:)
    return if docv_result_response.nil?

    analytics.idv_socure_verification_data_requested(
      **filtered_verification_data(docv_result_response).merge(
        docv_transaction_token: document_capture_session.socure_docv_transaction_token,
        submit_attempts: rate_limiter&.attempts,
        remaining_submit_attempts: rate_limiter&.remaining_count,
        vendor_request_time_in_ms:,
        async:,
      ).compact,
    )
  end

  def filtered_verification_data(docv_result_response)
    hash = docv_result_response.to_h
    hash.delete(:attention_with_barcode)
    hash.delete(:selfie_live)
    hash.delete(:selfie_quality_good)
    hash.delete(:selfie_status)
    hash
  end

  def socure_document_verification_result
    DocAuth::Socure::Requests::DocvResultRequest.new(
      document_capture_session_uuid:,
    ).fetch
  end

  def document_capture_session
    @document_capture_session ||=
      DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
  end

  def rate_limiter
    return unless document_capture_session

    @rate_limiter ||= RateLimiter.new(
      user: document_capture_session.user,
      rate_limit_type: :idv_doc_auth,
    )
  end
end
