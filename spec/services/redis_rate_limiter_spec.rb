require 'rails_helper'

RSpec.describe RedisRateLimiter do
  let(:now) { Time.zone.now }

  around do |ex|
    REDIS_THROTTLE_POOL.with { |client| client.flushdb }
    ex.run
    REDIS_THROTTLE_POOL.with { |client| client.flushdb }
  end

  let(:key) { 'some-unique-identifier' }
  let(:interval) { 5.seconds }
  let(:max_requests) { 5 }

  subject(:rate_limiter) do
    RedisRateLimiter.new(
      key:,
      max_requests:,
      interval:,
    )
  end

  describe '#attempt!' do
    it 'calls the block when the limit has not been hit' do
      called = false

      rate_limiter.attempt!(now) do
        called = true
      end

      expect(called).to eq(true)
    end

    it 'raises an error and does not run the block when the limit has been hit' do
      called_count = 0

      max_requests.times do
        rate_limiter.attempt!(now) do
          called_count += 1
        end
      end

      expect(called_count).to eq(max_requests)

      expect do
        rate_limiter.attempt!(now) do
          called_count += 1
        end
      end.to raise_error(RedisRateLimiter::LimitError)

      expect(called_count).to eq(max_requests)
    end
  end

  describe '#maxed?' do
    context 'when the key does not exist in redis' do
      it 'is false' do
        expect(rate_limiter.maxed?(now)).to eq(false)
      end
    end

    context 'when the key exists and is under the limit' do
      before do
        REDIS_THROTTLE_POOL.with { |r| r.set(rate_limiter.build_key(now), '1') }
      end

      it 'is false' do
        expect(rate_limiter.maxed?(now)).to eq(false)
      end
    end

    context 'when the key exists and is at the limit' do
      before do
        REDIS_THROTTLE_POOL.with { |r| r.set(rate_limiter.build_key(now), max_requests) }
      end

      it 'is true' do
        expect(rate_limiter.maxed?(now)).to eq(true)
      end
    end
  end

  describe '#increment' do
    context 'when the key does not exist in redis' do
      it 'sets the value to 1 when' do
        expect { rate_limiter.increment(now) }.to(
          change { REDIS_THROTTLE_POOL.with { |r| r.get(rate_limiter.build_key(now)) } }.
            from(nil).to('1'),
        )
      end
    end

    context 'when the key exists in redis' do
      before do
        REDIS_THROTTLE_POOL.with { |r| r.set(rate_limiter.build_key(now), '3') }
      end

      it 'increments the value' do
        expect { rate_limiter.increment(now) }.to(
          change { REDIS_THROTTLE_POOL.with { |r| r.get(rate_limiter.build_key(now)) } }.to('4'),
        )
      end
    end

    it 'sets the TTL of the key to interval minus 1' do
      rate_limiter.increment(now)

      ttl = REDIS_THROTTLE_POOL.with { |r| r.ttl(rate_limiter.build_key(now)) }
      expect(ttl).to be_within(1).of(interval - 1) # allow for some clock drift in specs
    end
  end
end
