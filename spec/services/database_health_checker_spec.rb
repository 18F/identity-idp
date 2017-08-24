require 'rails_helper'

RSpec.describe DatabaseHealthChecker do
  describe '.check' do
    subject(:summary) { DatabaseHealthChecker.check }

    context 'when the database is healthy' do
      it 'returns a healthy check' do
        expect(summary.result).to eq([1])
        expect(summary.healthy).to eq(true)
      end
    end

    context 'when the database is unhealthy' do
      before do
        expect(DatabaseHealthChecker).to receive(:simple_query).
          and_raise(RuntimeError.new('canceling statement due to statement timeout'))
      end

      it 'returns an unhealthy check' do
        expect(summary.healthy).to eq(false)
        expect(summary.result).to include('canceling statement due to statement timeout')
      end

      it 'notifies NewRelic' do
        expect(NewRelic::Agent).to receive(:notice_error)

        summary
      end
    end
  end
end
