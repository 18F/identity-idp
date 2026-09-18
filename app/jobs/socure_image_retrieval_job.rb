# frozen_string_literal: true

class SocureImageRetrievalJob < ApplicationJob
  queue_as :default

  attr_reader :document_capture_session_uuid

  def perform(
    document_capture_session_uuid:,
    reference_id:,
    image_storage_data:,
    passport_book:,
    persist_artifacts: false,
    docv_transaction_token: nil
  )
    @document_capture_session_uuid = document_capture_session_uuid
    @docv_transaction_token = docv_transaction_token

    result = fetch_images(reference_id, passport_book:)
    if result.is_a?(Idv::IdvImages)
      result.write_with_data(image_storage_data:)
      persist_document_artifacts(result:, image_storage_data:) if persist_artifacts
    else
      failure_msg = result.dig(:extra, :vendor_status_message, 'msg') || 'Unknown network error'
      attempts_api_tracker.idv_image_retrieval_failed(
        document_back_image_file_id: image_storage_data.dig(:back, :document_back_image_file_id),
        document_front_image_file_id: image_storage_data.dig(:front, :document_front_image_file_id),
        document_passport_image_file_id: image_storage_data.dig(
          :passport,
          :document_passport_image_file_id,
        ),
        document_selfie_image_file_id: image_storage_data.dig(
          :selfie,
          :document_selfie_image_file_id,
        ),
        failure_reason: [{ api_failure: failure_msg }],
      )
      fraud_ops_tracker.idv_image_retrieval_failed(
        document_back_image_file_id: image_storage_data.dig(:back, :document_back_image_file_id),
        document_front_image_file_id: image_storage_data.dig(:front, :document_front_image_file_id),
        document_passport_image_file_id: image_storage_data.dig(
          :passport,
          :document_passport_image_file_id,
        ),
        document_selfie_image_file_id: image_storage_data.dig(
          :selfie,
          :document_selfie_image_file_id,
        ),
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
      sp_redirect_uri: nil,
      enabled_for_session: sp&.attempts_api_enabled?,
    )
  end

  def fraud_ops_tracker
    @fraud_ops_tracker ||= FraudOps::Tracker.new(
      request: nil,
      user: document_capture_session.user,
      sp:,
      cookie_device_uuid: nil,
    )
  end

  def document_capture_session
    @document_capture_session ||=
      DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
  end

  # Only called for a successful verification, so the persisted set always
  # reflects the document that actually passed. Any artifacts left over from an
  # earlier failed attempt on this capture session (e.g. a rejected DL before a
  # successful passport) are pruned so they can never be shared.
  # Idempotent on retry: keyed on capture session + image type.
  # Persisted only when the initiating SP is allow-listed for image sharing
  # (data minimization: no key material is stored for anyone else) and never
  # for mDL flows, which produce no shareable artifacts.
  #
  # Runs inside a transaction that first takes a row lock on the capture session.
  # Idv::Session stamps the same row (update_column) inside ITS transaction when
  # it creates the profile, so the two serialize on that lock: whichever runs
  # second sees the other's committed work, and the artifacts always end up
  # linked. Without the lock a READ COMMITTED re-read can observe the stamp as
  # nil while the stamping transaction is still open, orphaning the rows.
  def persist_document_artifacts(result:, image_storage_data:)
    return unless document_capture_session
    return unless sp&.document_images_sharing_allowed?

    DocumentCaptureSession.transaction do
      # All state checks read the FOR UPDATE row, never the memoized record.
      locked_session = DocumentCaptureSession.lock.find_by(id: document_capture_session.id)
      return if locked_session.nil? || locked_session.mdl_requested?
      # A redo starts a new Socure transaction on the same capture session. If the
      # session has moved on since this job was enqueued, this job describes a
      # superseded attempt and must not overwrite the newer verification's images.
      # A blank token cannot prove which attempt this is, so it also skips.
      return if @docv_transaction_token.blank?
      return if locked_session.socure_docv_transaction_token != @docv_transaction_token

      artifacts = locked_session.document_artifacts

      persisted_types = image_storage_data.keys.map(&:to_s)
      artifacts.where.not(image_type: persisted_types).destroy_all

      image_storage_data.each do |type, data|
        image = result.public_send(type)

        if image.blank?
          artifacts.where(image_type: type.to_s).destroy_all
          next
        end

        artifact = artifacts.find_or_initialize_by(image_type: type.to_s)
        # created_at drives the `retained` window and is refreshed here because
        # write_with_data above rewrote the same S3 key, restarting the object's
        # lifecycle clock. Keep these two in step: if the escrow write ever becomes
        # conditional, this refresh must become conditional with it.
        artifact.update!(
          storage_name: data[image.attempts_tracker_file_id_key],
          encryption_key: data[image.attempts_tracker_encryption_key],
          created_at: Time.zone.now,
        )
      end

      associate_artifacts_with_producing_profile(locked_session)
    end
  end

  # Normally Idv::Session links artifacts when it creates the profile, but under
  # worker backlog this job can finish AFTER that. Idv::Session also stamps the
  # capture session with the profile it produced, so we reconcile strictly from
  # that stamp: only this session's rows, only to the profile this exact session
  # produced. Never inferred from timestamps or from the user's active profile.
  # `locked_session` was loaded FOR UPDATE, so its profile_id is authoritative.
  def associate_artifacts_with_producing_profile(locked_session)
    profile_id = locked_session.profile_id
    return if profile_id.nil?

    # rubocop:disable Rails/SkipsModelValidations
    locked_session.document_artifacts.where(profile_id: nil).update_all(profile_id:)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def fetch_images(reference_id, passport_book:)
    DocAuth::Socure::Requests::ImagesRequest.new(
      reference_id:,
      passport_book:,
    ).fetch
  end

  def sp
    @sp ||= ServiceProvider.find_by(issuer: document_capture_session.issuer)
  end
end
