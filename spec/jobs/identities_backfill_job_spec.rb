require 'rails_helper'

RSpec.describe IdentitiesBackfillJob, type: :job do
  describe '#perform' do
    it 'does not update rows that have been soft-deleted' do
      #
    end

    it 'does not update rows that already have a date populated' do
      #
    end

    it 'does update rows which are not deleted and have no last_consented_at date' do
      #
    end

    context 'when batch_size is set in redis' do
      it 'uses that batch size' do
        #
      end
    end

    context 'when the counter hits 185 million' do
      it 'returns without running any queries' do
        #
      end
    end
  end
end
