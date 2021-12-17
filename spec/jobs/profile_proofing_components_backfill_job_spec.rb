require 'rails_helper'

RSpec.describe ProfileProofingComponentsBackfillJob do
  describe '#perform' do
    let(:old_updated_at) { 3.days.ago }
    let(:now) { Time.zone.now }

    it 'backfills data that was double-encoded as JSON' do
      json_str = create(
        :profile,
        proofing_components: { 'foo' => true }.to_json,
        updated_at: old_updated_at,
      )
      json_obj = create(
        :profile,
        proofing_components: { 'foo' => true },
        updated_at: old_updated_at,
      )
      blank_val = create(:profile, proofing_components: '', updated_at: old_updated_at)
      nil_val = create(:profile, proofing_components: nil, updated_at: old_updated_at)

      expect(Rails.logger).to receive(:info).with(
        {
          name: 'profile_proofing_components_update_batch',
          batch_size: 4,
          batch_updated: 2,
          batch_start: json_str.id,
          batch_end: nil_val.id,
        }.to_json,
      )

      ProfileProofingComponentsBackfillJob.new.perform

      json_str.reload
      expect(json_str.read_attribute(:proofing_components)).to eq('foo' => true)
      expect(json_str.updated_at.to_i).to be_within(1).of(now.to_i)

      json_obj.reload
      expect(json_obj.read_attribute(:proofing_components)).to eq('foo' => true)
      expect(json_obj.updated_at.to_i).
        to eq(old_updated_at.to_i), 'does not update correctly-encoded rows'

      blank_val.reload
      expect(blank_val.read_attribute(:proofing_components)).to eq(nil)
      expect(blank_val.updated_at.to_i).to be_within(1).of(now.to_i)

      nil_val.reload
      expect(nil_val.read_attribute(:proofing_components)).to eq(nil)
      expect(nil_val.updated_at.to_i).
        to eq(old_updated_at.to_i), 'does not update rows with nil values'
    end
  end
end
