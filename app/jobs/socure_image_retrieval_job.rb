# frozen_string_literal: true

class SocureImageRetrievalJob < ApplicationJob
  queue_as :high_socure_docv

  attr_reader :document_capture_session_uuid

  def perform(
    document_capture_session_uuid:,
    reference_id:,
    image_storage_data:
  )
    @document_capture_session_uuid = document_capture_session_uuid

    result = fetch_images(reference_id)
    if result.is_a?(Idv::IdvImages)
      result.write_with_data(image_storage_data:)
    else
      attempts_api_tracker.idv_image_retrieval_failed(
        **image_storage_data,
      )
    end
  end

  def attempts_api_tracker
    @attempts_api_tracker ||= AttemptsApi::Tracker.new(
      session_id: nil,
      request: nil,
      user: document_capture_session.user,
      sp:,
      cookie_device_uuid: nil,
      sp_request_uri: nil,
      enabled_for_session: sp&.attempts_api_enabled?,
    )
  end

  def document_capture_session
    @document_capture_session ||=
      DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
  end

  def fetch_images(reference_id)
    DocAuth::Socure::Requests::ImagesRequest.new(
      reference_id:,
    ).fetch
  end

  def sp
    @sp ||= ServiceProvider.find_by(issuer: document_capture_session.issuer)
  end
end
