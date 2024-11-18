# frozen_string_literal: true

class SocureDocvResultsJob < ApplicationJob
  queue_as :high_socure_docv

  attr_reader :document_capture_session_uuid

  # @param [String] document_capture_session_uuid
  def perform(document_capture_session_uuid:)
    @document_capture_session_uuid = document_capture_session_uuid

    dcs = DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
    raise "DocumentCaptureSession not found: #{document_capture_session_uuid}" if !dcs

    @analytics = create_analytics(
      user: dcs.user,
      service_provider_issuer: dcs.issuer,
    )
    #puts 'in perform'
    
    #timer = JobHelpers::Timer.new
    #response = timer.time('vendor_request') do
    #  socure_document_verification_result
    #end
    #log_verification_request(response)
    result = socure_document_verification_result
    dcs.store_result_from_response(result)
    #dcs.store_result_from_response(response)
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

  def log_verification_request(docv_result_response)
    return if docv_result_response.nil?

    puts 'in log_verification_request'
    verification_response_data = docv_result_response.verification_response_data
    puts "Response: #{verification_response_data}"
    @analytics.idv_socure_verification_data_requested(
      **verification_response_data.to_h,
    )
  end

  def socure_document_verification_result
    DocAuth::Socure::Requests::DocvResultRequest.new(
      document_capture_session_uuid:,
    ).fetch
  end
end
