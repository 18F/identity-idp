# frozen_string_literal: true

module Idv
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
        locked_session = DocumentCaptureSession.lock.find_by(id: document_capture_session.id)
        return if locked_session.nil? || locked_session.mdl_requested?
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

      superseded_names.each { |name| redis_storage.delete_image(name:) }
    end

    private

    def persist_document_metadata(locked_session)
      return if document_metadata.blank?

      metadata = locked_session.document_metadata ||
                 locked_session.build_document_metadata
      metadata.document_data = document_metadata
      metadata.created_at = Time.zone.now
      metadata.save!
    end

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
