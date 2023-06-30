require 'rails_helper'

RSpec.describe RateLimit do
  let(:throttle_type) { :idv_doc_auth }
  let(:max_attempts) { 3 }
  let(:attempt_window) { 10 }
  before(:each) do
    allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
    allow(IdentityConfig.store).to receive(:doc_auth_attempt_window_in_minutes).
      and_return(attempt_window)
  end

  describe '.new' do
    context 'when target is a string' do
      subject(:for_target) { RateLimit.new(target: target, throttle_type: throttle_type) }

      context 'target is not a string' do
        it 'raises an error' do
          expect { RateLimit.new(target: 3, throttle_type: throttle_type) }.
            to raise_error(ArgumentError)
        end
      end
    end

    it 'throws an error when neither user nor target are provided' do
      expect { RateLimit.new(throttle_type: throttle_type) }.
        to raise_error(
          ArgumentError,
          'RateLimit must have a user or a target, but neither were provided',
        )
    end

    it 'throws an error when both user and target are provided' do
      expect { RateLimit.new(throttle_type: throttle_type) }.
        to raise_error(
          ArgumentError,
          'RateLimit must have a user or a target, but neither were provided',
        )
    end

    it 'throws an error for an invalid throttle_type' do
      expect { RateLimit.new(throttle_type: :abc_123, target: '1') }.
        to raise_error(
          ArgumentError,
          'throttle_type is not valid',
        )
    end
  end

  describe '.attempt_window_in_minutes' do
    it 'returns configured attempt window for throttle type' do
      expect(RateLimit.attempt_window_in_minutes(throttle_type)).to eq(attempt_window)
    end

    it 'is indifferent to throttle type stringiness' do
      expect(RateLimit.attempt_window_in_minutes(throttle_type.to_s)).to eq(attempt_window)
    end
  end

  describe '.max_attempts' do
    it 'returns configured attempt window for throttle type' do
      expect(RateLimit.max_attempts(throttle_type)).to eq(max_attempts)
    end

    it 'is indifferent to throttle type stringiness' do
      expect(RateLimit.max_attempts(throttle_type.to_s)).to eq(max_attempts)
    end
  end

  describe '#increment!' do
    subject(:throttle) { RateLimit.new(target: 'aaa', throttle_type: :idv_doc_auth) }
    let(:max_attempts) { 1 } # Picked up by before block at top of test file

    it 'increments attempts' do
      expect(throttle.attempts).to eq 0
      throttle.increment!
      expect(throttle.attempts).to eq 1
    end

    it 'does nothing if already throttled' do
      expect(throttle.attempts).to eq 0
      throttle.increment!
      expect(throttle.attempts).to eq 1
      expect(throttle.throttled?).to eq(true)
      current_expiration = throttle.expires_at
      travel 5.minutes do # move within 10 minute expiration window
        throttle.increment!
        expect(throttle.attempts).to eq 1
        expect(throttle.expires_at).to eq current_expiration
      end
    end
  end

  describe '#throttled?' do
    let(:throttle_type) { :idv_doc_auth }
    let(:max_attempts) { RateLimit.max_attempts(throttle_type) }
    let(:attempt_window_in_minutes) { RateLimit.attempt_window_in_minutes(throttle_type) }

    subject(:throttle) { RateLimit.new(target: '1', throttle_type: throttle_type) }

    it 'returns true if throttled' do
      max_attempts.times do
        throttle.increment!
      end

      expect(throttle.throttled?).to eq(true)
    end

    it 'returns false if the attempts < max_attempts' do
      (max_attempts - 1).times do
        expect(throttle.throttled?).to eq(false)
        throttle.increment!
      end

      expect(throttle.throttled?).to eq(false)
    end

    it 'returns false if the attempts <= max_attempts but the window is expired' do
      max_attempts.times do
        throttle.increment!
      end

      travel(attempt_window_in_minutes.minutes + 1) do
        expect(throttle.throttled?).to eq(false)
      end
    end
  end

  describe '#expires_at' do
    let(:attempted_at) { nil }
    let(:throttle) { RateLimit.new(target: '1', throttle_type: throttle_type) }

    context 'without having attempted' do
      it 'returns current time' do
        freeze_time do
          expect(throttle.expires_at).to eq(Time.zone.now)
        end
      end
    end

    context 'with expired throttle' do
      it 'returns expiration time' do
        throttle.increment!

        travel_to(throttle.attempted_at + 3.days) do
          expect(throttle.expires_at).to be_within(1.second).
            of(throttle.attempted_at + attempt_window.minutes)
        end
      end
    end

    context 'with active throttle' do
      it 'returns expiration time' do
        freeze_time do
          throttle.increment!
          expect(throttle.expires_at).to be_within(1.second).
            of(throttle.attempted_at + attempt_window.minutes)
        end
      end
    end
  end

  describe '#reset' do
    let(:target) { '1' }
    let(:subject) { described_class }

    subject(:throttle) { RateLimit.new(target: target, throttle_type: throttle_type) }

    it 'resets attempt count to 0' do
      throttle.increment!

      expect { throttle.reset! }.to change { throttle.attempts }.to(0)
    end
  end

  describe '#remaining_count' do
    let(:target) { '1' }
    let(:subject) { described_class }

    subject(:throttle) { RateLimit.new(target: target, throttle_type: throttle_type) }

    it 'returns maximium remaining attempts with zero attempts' do
      expect(throttle.remaining_count).to eq(RateLimit.max_attempts(throttle_type))
    end

    it 'returns zero when throttle limit is reached' do
      throttle.increment_to_throttled!
      expect(throttle.remaining_count).to eq(0)
    end
  end
end
