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

    result = socure_document_verification_result
    dcs.store_result_from_response(result)
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

  def socure_document_verification_result
    DocAuth::Socure::Requests::DocvResultRequest.new(
      document_capture_session_uuid:,
      analytics: @analytics,
    ).fetch
  end
end
