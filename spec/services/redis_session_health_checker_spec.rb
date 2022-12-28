require 'rails_helper'

RSpec.describe RedisSessionHealthChecker do
  describe '.check' do
    subject(:summary) { RedisSessionHealthChecker.check }

    context 'when the redis session store is healthy' do
      it 'returns a healthy check' do
        expect(summary.healthy).to eq(true)
        expect(summary.result).to start_with("healthy at ")
      end
    end

    context 'when the redis session store is unhealthy' do
      before do
        expect(RedisSessionHealthChecker).to receive(:simple_query).
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
