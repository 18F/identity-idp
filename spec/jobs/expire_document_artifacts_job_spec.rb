require 'rails_helper'

RSpec.describe ExpireDocumentArtifactsJob do
  let(:retention_days) { 90 }
  let(:analytics) { FakeAnalytics.new }

  subject(:job) { described_class.new }

  before do
    allow(IdentityConfig.store).to receive(:document_images_retention_days)
      .and_return(retention_days)
    allow(job).to receive(:analytics).and_return(analytics)
  end

  describe '#perform' do
    let!(:fresh) { create(:document_artifact, created_at: (retention_days - 1).days.ago) }
    let!(:expired) { create(:document_artifact, created_at: (retention_days + 1).days.ago) }
    let!(:fresh_metadata) { create(:document_metadata, created_at: (retention_days - 1).days.ago) }
    let!(:expired_metadata) do
      create(:document_metadata, created_at: (retention_days + 1).days.ago)
    end

    it 'deletes only aged artifacts and metadata and logs the counts' do
      job.perform(Time.zone.now)

      expect(DocumentArtifact.exists?(fresh.id)).to eq(true)
      expect(DocumentArtifact.exists?(expired.id)).to eq(false)
      expect(DocumentMetadata.exists?(fresh_metadata.id)).to eq(true)
      expect(DocumentMetadata.exists?(expired_metadata.id)).to eq(false)
      expect(analytics).to have_logged_event(
        :document_artifacts_expired,
        deleted_count: 1,
        deleted_metadata_count: 1,
      )
    end
  end
end
