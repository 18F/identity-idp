# frozen_string_literal: true

# Deletes document_artifacts rows (and their wrapped AES keys) once the
# underlying escrow objects have aged past the S3 lifecycle, so the DB never
# holds key material for images that no longer exist.
class ExpireDocumentArtifactsJob < ApplicationJob
  queue_as :low

  def perform(_now)
    deleted_count = DocumentArtifact.expired.in_batches.delete_all

    analytics.document_artifacts_expired(deleted_count:)
  end

  private

  def analytics
    Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
  end
end
