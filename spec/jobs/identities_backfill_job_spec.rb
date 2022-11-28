require 'rails_helper'

RSpec.describe IdentitiesBackfillJob, type: :job do
  describe '#perform' do
    let!(:deleted) do
      create(:service_provider_identity, :soft_deleted_5m_ago, :consented)
    end

    let!(:consented_at_set) do
      create(:service_provider_identity, :consented)
    end

    let!(:no_consented_at) do
      create(:service_provider_identity, :active)
    end

    subject { described_class.perform_now }

    it 'does not update rows that have been soft-deleted' do
      expect(deleted.deleted_at).to_not be_nil
      consent_time = deleted.last_consented_at.to_i

      subject
      deleted.reload

      expect(deleted.deleted_at).not_to be_nil
      expect(deleted.last_consented_at.to_i).to eq(consent_time)
    end

    it 'does not update rows that already have a date populated' do
      time = consented_at_set.last_consented_at
      expect(time).not_to be_nil

      subject

      expect(consented_at_set.reload.last_consented_at.to_i).to eq time.to_i
    end

    it 'does update rows which are not deleted and have no last_consented_at date' do
      expect(no_consented_at.last_consented_at).to be_nil
      expect(no_consented_at.created_at).to_not be_nil
      expect(no_consented_at.deleted_at).to be_nil

      subject

      expect(no_consented_at.reload.last_consented_at).to_not be_nil
    end

    context 'when the batch size is small' do
      let(:batch_size) { 2 }
      let(:slice_size) { 1 }
      before do
        REDIS_POOL.with do |redis|
          redis.set(IdentitiesBackfillJob::BATCH_SIZE_KEY, batch_size)
          redis.set(IdentitiesBackfillJob::SLICE_SIZE_KEY, slice_size)
          redis.set(
            IdentitiesBackfillJob::CACHE_KEY,
            ServiceProviderIdentity.first.id - 1,
          )
        end
      end

      it 'increments position by a bit (make this less vague)' do
        # The first time around, the position should match the second row:
        described_class.perform_now
        position = described_class.new.position
        expect(position).to eq(ServiceProviderIdentity.second.id)

        # The second time, we finish the table, so position should point past the end:
        described_class.perform_now
        expect(described_class.new.position).to eq(position + batch_size)
      end
    end

    context 'when done updating the database' do
      it 'updates the position in Redis' do
        expect(described_class.new.position).to eq(0)

        subject

        expect(described_class.new.position).to eq(ServiceProviderIdentity.last.id)
      end
    end
  end

  describe '#batch_size' do
    subject { described_class.new.batch_size }

    context 'when there is no cache key in redis' do
      it 'returns the default of 500,000' do
        expect(subject).to eq(500_000)
      end
    end

    context 'when there is a cache key in redis' do
      before do
        REDIS_POOL.with do |redis|
          redis.set(described_class::BATCH_SIZE_KEY, 1000)
        end
      end

      it 'returns that value' do
        expect(subject).to eq 1000
      end
    end
  end
end
