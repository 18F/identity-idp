require 'rails_helper'

RSpec.describe Reports::CountHelper do
  describe '.count_in_batches' do
    let!(:records_in_scope) do
      10.times.map { create(:registration_log, registered_at: 3.days.ago) }
    end
    let!(:records_out_of_scope) do
      5.times.map { create(:registration_log, registered_at: 10.years.ago) }
    end

    let(:relation) do
      RegistrationLog.where(registered_at: (1.year.ago..Time.zone.now))
    end

    it 'counts the records in a relation' do
      expect(Reports::CountHelper.count_in_batches(relation)).to eq(records_in_scope.size)
    end

    it 'adds up across multiple batches' do
      expect(relation).to receive(:where).exactly(records_in_scope.size + 1).times.and_call_original

      expect(Reports::CountHelper.count_in_batches(relation, batch_size: 1)).
        to eq(records_in_scope.size)
    end

    it 'gets the correct count with missing intermediate ids' do
      first, *middle, last = records_in_scope
      middle.sample.destroy

      expect(Reports::CountHelper.count_in_batches(relation)).
          to eq(records_in_scope.count - 1)
    end
  end
end
