require 'rails_helper'

RSpec.describe Test::DeviceProfilingController do
  let(:session_id) { SecureRandom.uuid }

  around do |ex|
    REDIS_POOL.with { |namespaced| namespaced.redis.flushdb }
    ex.run
    REDIS_POOL.with { |namespaced| namespaced.redis.flushdb }
  end

  describe '#index' do
    it 'sets no_result for the session_id' do
      expect do
        get :index, params: { session_id: session_id }
      end.to(
        change { Proofing::Mock::DeviceProfilingBackend.new.profiling_result(session_id) }.
        from(nil).to('no_result'),
      )
    end
  end

  describe '#create' do
    let(:result) { 'pass' }

    it 'sets the result in redis' do
      expect do
        post :create, params: { session_id: session_id, result: result }
      end.to(
        change { Proofing::Mock::DeviceProfilingBackend.new.profiling_result(session_id) }.
        from(nil).to(result),
      )
    end
  end
end
