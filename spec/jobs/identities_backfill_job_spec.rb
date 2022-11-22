require 'rails_helper'

RSpec.describe IdentitiesBackfillJob, type: :job do
  describe '#perform' do
    # create a few rows
    let!(:deleted) do
      create(:service_provider_identity, :soft_deleted, :consented)
    end

    let!(:consented_at_set) do
      create(:service_provider_identity, :consented)
    end

    let!(:no_consented_at) do
      create(:service_provider_identity, :active)
    end

    it 'does not update rows that have been soft-deleted' do
      expect(deleted.deleted_at).to_not be_nil
      expect(deleted.last_consented_at).to be_nil

      IdentitiesBackfillJob.perform_now

      # Why is this failing?! The query should be straightforward!
      expect(deleted.reload.last_consented_at).to be_nil
    end

    it 'does not update rows that already have a date populated' do
      time = consented_at_set.last_consented_at
      expect(time).not_to be_nil

      IdentitiesBackfillJob.perform_now

      expect(consented_at_set.reload.last_consented_at).to eq time
    end

    it 'does update rows which are not deleted and have no last_consented_at date' do
      expect(no_consented_at.last_consented_at).to be_nil
      expect(no_consented_at.created_at).to_not be_nil
      expect(no_consented_at.deleted_at).to be_nil

      IdentitiesBackfillJob.perform_now

      expect(no_consented_at.reload.last_consented_at).to_not be_nil
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
          redis.set(IdentitiesBackfillJob::BATCH_SIZE_KEY, 1000)
        end
      end

      it 'returns that value' do
        expect(subject).to eq 1000
      end
    end
  end
end
