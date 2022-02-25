require 'rails_helper'

RSpec.describe OutOfBandSessionAccessor do
  let(:session_uuid) { SecureRandom.uuid }

  subject(:store) { described_class.new(session_uuid) }

  around do |ex|
    REDIS_POOL.with { |namespaced| namespaced.redis.flushdb }
    ex.run
    REDIS_POOL.with { |namespaced| namespaced.redis.flushdb }
  end

  describe '#ttl' do
    it 'returns the remaining time-to-live of the session data in redis' do
      store.put({ foo: 'bar' }, 5.minutes.to_i)

      expect(store.ttl).to eq(5.minutes.to_i)
    end
  end

  describe '#load' do
    it 'loads the session' do
      store.put({ foo: 'bar' }, 5.minutes.to_i)

      session = store.load
      expect(session.dig('warden.user.user.session')).to eq('foo' => 'bar')
    end
  end

  describe '#destroy' do
    it 'destroys the session' do
      store.put({ foo: 'bar' }, 5.minutes.to_i)
      store.destroy

      expect(store.load).to be_empty
    end
  end
end
