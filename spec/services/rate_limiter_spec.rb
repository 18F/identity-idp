require 'rails_helper'

RSpec.describe RateLimiter do
  let(:rate_limit_type) { :idv_doc_auth }
  let(:max_attempts) { 3 }
  let(:attempt_window) { 10 }
  before(:each) do
    allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
    allow(IdentityConfig.store).to receive(:doc_auth_attempt_window_in_minutes)
      .and_return(attempt_window)
  end

  describe '.new' do
    context 'when target is a string' do
      subject(:for_target) { RateLimiter.new(target: target, rate_limit_type: rate_limit_type) }

      context 'target is not a string' do
        it 'raises an error' do
          expect { RateLimiter.new(target: 3, rate_limit_type: rate_limit_type) }
            .to raise_error(ArgumentError)
        end
      end
    end

    it 'throws an error when neither user nor target are provided' do
      expect { RateLimiter.new(rate_limit_type: rate_limit_type) }
        .to raise_error(
          ArgumentError,
          'RateLimiter must have a user or a target, but neither were provided',
        )
    end

    it 'throws an error when both user and target are provided' do
      expect { RateLimiter.new(rate_limit_type: rate_limit_type) }
        .to raise_error(
          ArgumentError,
          'RateLimiter must have a user or a target, but neither were provided',
        )
    end

    it 'throws an error for an invalid rate_limit_type' do
      expect { RateLimiter.new(rate_limit_type: :abc_123, target: '1') }
        .to raise_error(
          ArgumentError,
          'rate_limit_type is not valid',
        )
    end
  end

  describe '.attempt_window_in_minutes' do
    it 'returns configured attempt window for rate_limiter type' do
      expect(RateLimiter.attempt_window_in_minutes(rate_limit_type)).to eq(attempt_window)
    end

    it 'is indifferent to rate_limiter type stringiness' do
      expect(RateLimiter.attempt_window_in_minutes(rate_limit_type.to_s)).to eq(attempt_window)
    end
  end

  describe '.max_attempts' do
    it 'returns configured attempt window for rate_limiter type' do
      expect(RateLimiter.max_attempts(rate_limit_type)).to eq(max_attempts)
    end

    it 'is indifferent to rate_limiter type stringiness' do
      expect(RateLimiter.max_attempts(rate_limit_type.to_s)).to eq(max_attempts)
    end
  end

  describe '#increment!' do
    subject(:rate_limiter) { RateLimiter.new(target: 'aaa', rate_limit_type: :idv_doc_auth) }
    let(:max_attempts) { 1 } # Picked up by before block at top of test file

    it 'increments attempts' do
      expect(rate_limiter.attempts).to eq 0
      rate_limiter.increment!
      expect(rate_limiter.attempts).to eq 1
    end

    it 'does nothing if already rate limited' do
      expect(rate_limiter.attempts).to eq 0
      rate_limiter.increment!
      expect(rate_limiter.attempts).to eq 1
      expect(rate_limiter.limited?).to eq(true)
      current_expiration = rate_limiter.expires_at
      travel 5.minutes do # move within 10 minute expiration window
        rate_limiter.increment!
        expect(rate_limiter.attempts).to eq 1
        expect(rate_limiter.expires_at).to eq current_expiration
      end
    end
  end

  describe '#limited?' do
    let(:rate_limit_type) { :idv_doc_auth }
    let(:max_attempts) { RateLimiter.max_attempts(rate_limit_type) }
    let(:attempt_window_in_minutes) { RateLimiter.attempt_window_in_minutes(rate_limit_type) }

    subject(:rate_limiter) { RateLimiter.new(target: '1', rate_limit_type: rate_limit_type) }

    it 'returns true if rate limited' do
      max_attempts.times do
        rate_limiter.increment!
      end

      expect(rate_limiter.limited?).to eq(true)
    end

    it 'returns false if the attempts < max_attempts' do
      (max_attempts - 1).times do
        expect(rate_limiter.limited?).to eq(false)
        rate_limiter.increment!
      end

      expect(rate_limiter.limited?).to eq(false)
    end

    it 'returns false if the attempts <= max_attempts but the window is expired' do
      max_attempts.times do
        rate_limiter.increment!
      end

      travel(attempt_window_in_minutes.minutes + 1) do
        expect(rate_limiter.limited?).to eq(false)
      end
    end
  end

  describe '#expires_at' do
    let(:attempted_at) { nil }
    let(:rate_limiter) { RateLimiter.new(target: '1', rate_limit_type: rate_limit_type) }

    context 'without having attempted' do
      it 'returns nil' do
        expect(rate_limiter.expires_at).to eq(nil)
      end
    end

    context 'with expired rate_limiter' do
      it 'returns expiration time' do
        rate_limiter.increment!

        travel_to(rate_limiter.attempted_at + 3.days) do
          expect(rate_limiter.expires_at).to be_within(1.second)
            .of(rate_limiter.attempted_at + attempt_window.minutes)
        end
      end

      context 'when we are out of sync with Redis' do
        it 'expires at the correct time' do
          fake_attempt_time = 1.year.ago
          travel_to(fake_attempt_time) do
            # Redis should immediately delete the rate limiter because
            # we're supplying an expiration time which has long since
            # passed.
            rate_limiter.increment!
          end

          new_rate_limiter = RateLimiter.new(target: '1', rate_limit_type: rate_limit_type)
          expect(new_rate_limiter.expires_at).to be_nil
        end
      end
    end

    context 'with active rate_limiter' do
      it 'returns expiration time' do
        freeze_time do
          rate_limiter.increment!
          expect(rate_limiter.expires_at).to be_within(1.second)
            .of(rate_limiter.attempted_at + attempt_window.minutes)
        end
      end
    end
  end

  describe '#reset' do
    let(:target) { '1' }
    let(:subject) { described_class }

    subject(:rate_limiter) { RateLimiter.new(target: target, rate_limit_type: rate_limit_type) }

    it 'resets attempt count to 0' do
      rate_limiter.increment!

      expect { rate_limiter.reset! }.to change { rate_limiter.attempts }.to(0)
    end
  end

  describe '#remaining_count' do
    let(:target) { '1' }
    let(:subject) { described_class }

    subject(:rate_limiter) { RateLimiter.new(target: target, rate_limit_type: rate_limit_type) }

    it 'returns maximium remaining attempts with zero attempts' do
      expect(rate_limiter.remaining_count).to eq(RateLimiter.max_attempts(rate_limit_type))
    end

    it 'returns zero when rate_limiter limit is reached' do
      rate_limiter.increment_to_limited!
      expect(rate_limiter.remaining_count).to eq(0)
    end
  end

  context 'with exponential factor rate limit configuration' do
    let(:rate_limit_type) { :example_type }

    subject(:rate_limiter) { RateLimiter.new(target: '1', rate_limit_type:) }

    before do
      allow(RateLimiter).to receive(:rate_limit_config).and_return(
        example_type: {
          max_attempts: 10,
          attempt_window: 60,
          attempt_window_exponential_factor: 2,
          attempt_window_max: 24.hours.in_minutes,
        },
      )
    end

    it 'increases expiration exponentially by attempts', :freeze_time do
      # Attempt: 1
      # Assert default expiration
      rate_limiter.increment!
      expect(rate_limiter.expires_at).to eq(1.hour.from_now)

      # Attempt: 2
      # Assert exponential growth of expiration
      rate_limiter.increment!
      expect(rate_limiter.expires_at).to eq(2.hours.from_now)

      # Attempt: 3
      # Assert exponential growth of expiration
      rate_limiter.increment!
      expect(rate_limiter.expires_at).to eq(4.hours.from_now)

      # Attempt: 4, 5
      # Assert last expiration before reaching max attempt window
      2.times { rate_limiter.increment! }
      expect(rate_limiter.expires_at).to eq(16.hours.from_now)

      # Attempt: 6
      # Assert expiration upon reaching max attempt window, not limited
      rate_limiter.increment!
      expect(rate_limiter.expires_at).to eq(24.hours.from_now)
      expect(rate_limiter.limited?).to eq(false)

      # Attempt: 7, 8, 9
      # Assert expiration before reaching max attempts, not limited
      3.times { rate_limiter.increment! }
      expect(rate_limiter.expires_at).to eq(24.hours.from_now)
      expect(rate_limiter.limited?).to eq(false)

      # Attempt: 10
      # Assert expiration, limited upon reaching max attempts
      rate_limiter.increment!
      expect(rate_limiter.expires_at).to eq(24.hours.from_now)
      expect(rate_limiter.limited?).to eq(true)
    end
  end
end
