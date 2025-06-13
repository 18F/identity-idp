# frozen_string_literal: true

class SocureImageRetrievalJob < ApplicationJob
  queue_as :high_socure_docv

  attr_reader :document_capture_session_uuid

  def perform(
    reference_id:,
    document_capture_session_uuid:,
    failure_reason:,
    success:,
    pii_from_doc: {}
  )
    @document_capture_session_uuid = document_capture_session_uuid

    image_errors = {}

    if socure_doc_escrow_enabled?
      result = fetch_images(reference_id)
      if result.is_a?(Idv::IdvImages)
        images = result.attempts_file_data
      else
        image_errors = { image_request: [:network_error] }
      end
    else
      images = {}
    end

    attempts_api_tracker.idv_document_upload_submitted(
      **images,
      success:,
      document_state: pii_from_doc[:state],
      document_number: pii_from_doc[:state_id_number],
      document_issued: pii_from_doc[:state_id_issued],
      document_expiration: pii_from_doc[:state_id_expiration],
      first_name: pii_from_doc[:first_name],
      last_name: pii_from_doc[:last_name],
      date_of_birth: pii_from_doc[:dob],
      address1: pii_from_doc[:address1],
      address2: pii_from_doc[:address2],
      city: pii_from_doc[:city],
      state: pii_from_doc[:state],
      zip: pii_from_doc[:zipcode],
      failure_reason: failure_reason.merge(image_errors).presence,
    )
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

  def socure_doc_escrow_enabled?
    sp&.attempts_api_enabled? && IdentityConfig.store.socure_doc_escrow_enabled
  end
end
