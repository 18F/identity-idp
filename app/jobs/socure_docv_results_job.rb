# frozen_string_literal: true

class SocureDocvResultsJob
  # @param [String] document_capture_session_uuid
  # @param [String,nil] service_provider_issuer
  # @param [String] user_uuid
  def perform(
    document_capture_session_uuid:,
    service_provider_issuer:,
    user_uuid:
  )
    user = User.find_by(uuid: user_uuid)
    raise "User not found: #{user_uuid}" if !user

    dcs = DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
    raise "DocumentCaptureSession not found: #{document_capture_session_uuid}" if !dcs

    analytics = create_analytics(
      user:,
      service_provider_issuer:,
    )

    result = socure_document_verification_result

    if result.success?
      store_result_from_response(result)
    else
      analytics.track_event(
        Analytics::SOCURE_DOCUMENT_VERIFICATION_RESULT,
        { error: 'No result found' },
      )
    end
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
    Requests::DocvResultRequest.new(
      document_capture_session_uuid:,
    ).fetch
  end

  # def store_result_from_response(result:)
  #   DocumentCaptureSession.new(
  #     result_id: document_capture_session_result_id,
  #     ).load_proofing_result&.result
  # end
end
