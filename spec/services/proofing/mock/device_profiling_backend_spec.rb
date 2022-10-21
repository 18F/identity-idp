require 'rails_helper'

RSpec.describe Proofing::Mock::DeviceProfilingBackend do
  around do |ex|
    REDIS_POOL.with { |namespaced| namespaced.redis.flushdb }
    ex.run
    REDIS_POOL.with { |namespaced| namespaced.redis.flushdb }
  end

  subject(:backend) { described_class.new }
  let(:session_id) { SecureRandom.uuid }

  describe '#record_profiling_result' do
    it 'raises with unknown result' do
      expect { backend.record_profiling_result(session_id: session_id, result: 'aaa') }.
        to raise_error(ArgumentError)
    end

    it 'sets the value in redis' do
      backend.record_profiling_result(session_id: session_id, result: 'reject')

      expect(backend.profiling_result(session_id)).to eq('reject')

      expect(backend.profiling_result('different_id')).to be_nil
    end
  end
end
