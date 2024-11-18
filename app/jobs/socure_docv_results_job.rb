# frozen_string_literal: true

class SocureDocvResultsJob < ApplicationJob
  queue_as :high_socure_docv

  attr_reader :document_capture_session_uuid

  # @param [String] document_capture_session_uuid
  def perform(document_capture_session_uuid:, async: false)
    @document_capture_session_uuid = document_capture_session_uuid
    @async = async

    @dcs = DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
    raise "DocumentCaptureSession not found: #{document_capture_session_uuid}" if !@dcs

    @analytics = create_analytics(
      user: @dcs.user,
      service_provider_issuer: @dcs.issuer,
    )

    timer = JobHelpers::Timer.new
    response = timer.time('vendor_request') do
      socure_document_verification_result
    end
    log_verification_request(
      docv_result_response: response,
      vendor_request_time_in_ms: timer.results['vendor_request'],
    )
    @dcs.store_result_from_response(response)
  end

  def perform_later(document_capture_session_uuid:, async: true)
    perform(document_capture_session_uuid: document_capture_session_uuid, async: async)
  end

  private

  def create_analytics(
    user:,
    service_provider_issuer:
  )
    Analytics.new(
      user:,
      request: nil,
      sp: service_provider_issuer,
      session: {},
    )
  end

  def log_verification_request(docv_result_response:, vendor_request_time_in_ms:)
    return if docv_result_response.nil?

    response_hash = docv_result_response.to_h
    verification_response_data = docv_result_response.verification_response_data
    further_metrics = {
      user_id: @dcs.user.uuid,
      docv_transaction_token: @dcs.socure_docv_transaction_token,
      submit_attempts: rate_limiter&.attempts,
      remaining_submit_attempts: rate_limiter&.remaining_count,
      vendor_request_time_in_ms: vendor_request_time_in_ms,
      async: @async,
      success: response_hash[:success],
      errors: response_hash[:errors],
      exception: response_hash[:exception],
    }
    @analytics.idv_socure_verification_data_requested(
      **verification_response_data.to_h.merge(further_metrics),
    )
  end

  def socure_document_verification_result
    DocAuth::Socure::Requests::DocvResultRequest.new(
      document_capture_session_uuid:,
    ).fetch
  end

  def document_capture_session
    @document_capture_session ||=
      DocumentCaptureSession.find_by!(uuid: document_capture_session_uuid)
  end

  def rate_limiter
    return nil if document_capture_session.nil?

    @rate_limiter ||= RateLimiter.new(
      user: document_capture_session&.user,
      rate_limit_type: :idv_doc_auth,
    )
  end
end
