# frozen_string_literal: true

module Idv
  # Persists the shareable document artifacts (encrypted images + document
  # metadata) for a successful verification on a document capture session.
  #
  # Only called for a successful verification, so the persisted set always
  # reflects the document that actually passed. Any artifacts left over from an
  # earlier failed attempt on this capture session (e.g. a rejected DL before a
  # successful passport) are pruned so they can never be shared.
  # Idempotent on retry: keyed on capture session + image type.
  # Persisted only when the initiating SP is allow-listed for image sharing
  # (data minimization: nothing is stored for anyone else) and never for mDL
  # flows, which produce no shareable artifacts.
  #
  # Images are encrypted under a fresh per-image AES key and written to the IdV
  # Redis instance with a TTL (document_images_ttl_seconds); this is independent
  # of the doc escrow S3 bucket, which may not be enabled for the SP at all.
  #
  # Runs inside a transaction that first takes a row lock on the capture session.
  # Idv::Session stamps the same row (update_column) inside ITS transaction when
  # it creates the profile, so the two serialize on that lock: whichever runs
  # second sees the other's committed work, and the artifacts always end up
  # linked. Without the lock a READ COMMITTED re-read can observe the stamp as
  # nil while the stamping transaction is still open, orphaning the rows.
  class DocumentArtifactsPersister
    attr_reader :document_capture_session, :docv_transaction_token, :document_metadata

    # @param [DocumentCaptureSession, nil] document_capture_session
    # @param [String, nil] docv_transaction_token the Socure transaction the images belong to
    # @param [Hash, nil] document_metadata document identifiers (see DocumentMetadata::FIELDS)
    def initialize(document_capture_session:, docv_transaction_token:, document_metadata: nil)
      @document_capture_session = document_capture_session
      @docv_transaction_token = docv_transaction_token
      @document_metadata = document_metadata
    end

    # @param [Array<Idv::IdvImage>] images the images returned for the verified document
    def call(images:)
      return unless document_capture_session
      return unless document_capture_session.document_images_sharing_allowed?

      superseded_names = []

      DocumentCaptureSession.transaction do
        # All state checks read the FOR UPDATE row, never the caller's record.
        locked_session = DocumentCaptureSession.lock.find_by(id: document_capture_session.id)
        return if locked_session.nil? || locked_session.mdl_requested?
        # A redo starts a new Socure transaction on the same capture session. If the
        # session has moved on since this job was enqueued, this job describes a
        # superseded attempt and must not overwrite the newer verification's images.
        # A blank token cannot prove which attempt this is, so it also skips.
        return if docv_transaction_token.blank?
        return if locked_session.socure_docv_transaction_token != docv_transaction_token

        artifacts = locked_session.document_artifacts

        present_images = images.select { |image| image.bytes.present? }
        present_types = present_images.map { |image| image.type.to_s }
        artifacts.where.not(image_type: present_types).find_each do |stale|
          superseded_names << stale.storage_name
          stale.destroy!
        end

        present_images.each do |image|
          artifact = artifacts.find_or_initialize_by(image_type: image.type.to_s)
          superseded_names << artifact.storage_name if artifact.storage_name.present?

          stored = document_image_writer.write(image: image.bytes)
          # created_at drives the `retained` window; a fresh object was just written
          # with a full TTL, so the row's clock restarts with it.
          artifact.update!(
            storage_name: stored.name,
            encryption_key: stored.encryption_key,
            created_at: Time.zone.now,
          )
        end

        persist_document_metadata(locked_session)
        associate_artifacts_with_producing_profile(locked_session)
      end

      # Only after commit: a rollback must leave the previously served objects intact.
      superseded_names.each { |name| redis_storage.delete_image(name:) }
    end

    private

    # Document identifiers (number, issue/expiration dates) accompany the images
    # for adjudication. Stored encrypted, one row per capture session, refreshed on
    # each successful attempt so it always reflects the document that passed.
    def persist_document_metadata(locked_session)
      return if document_metadata.blank?

      metadata = locked_session.document_metadata ||
                 locked_session.build_document_metadata
      metadata.document_data = document_metadata
      metadata.created_at = Time.zone.now
      metadata.save!
    end

    # Normally Idv::Session links artifacts when it creates the profile, but under
    # worker backlog this can run AFTER that. Idv::Session also stamps the
    # capture session with the profile it produced, so we reconcile strictly from
    # that stamp: only this session's rows, only to the profile this exact session
    # produced. Never inferred from timestamps or from the user's active profile.
    # `locked_session` was loaded FOR UPDATE, so its profile_id is authoritative.
    def associate_artifacts_with_producing_profile(locked_session)
      profile_id = locked_session.profile_id
      return if profile_id.nil?

      # rubocop:disable Rails/SkipsModelValidations
      locked_session.document_artifacts.where(profile_id: nil).update_all(profile_id:)
      locked_session.document_metadata&.update_column(:profile_id, profile_id) if
        locked_session.document_metadata&.profile_id.nil?
      # rubocop:enable Rails/SkipsModelValidations
    end

    def document_image_writer
      @document_image_writer ||= EncryptedDocStorage::DocWriter.new(storage: redis_storage)
    end

    def redis_storage
      @redis_storage ||= EncryptedDocStorage::RedisStorage.new
    end
  end
end
