# frozen_string_literal: true

# Deletes document_artifacts and document_metadata rows (and their encrypted
# key material / identifiers) once they have aged past the escrow retention
# window, so the DB never holds data for images that no longer exist.
class ExpireDocumentArtifactsJob < ApplicationJob
  queue_as :low

  def perform(_now)
    deleted_count = DocumentArtifact.expired.in_batches.delete_all
    deleted_metadata_count = DocumentMetadata.expired.in_batches.delete_all

    analytics.document_artifacts_expired(
      deleted_count:,
      deleted_metadata_count:,
    )
  end

  private

  def analytics
    Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
  end
end
