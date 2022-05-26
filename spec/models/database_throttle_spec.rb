require 'rails_helper'

RSpec.describe DatabaseThrottle do
  let(:throttle_type) { :idv_doc_auth }
  let(:max_attempts) { 3 }
  let(:attempt_window) { 10 }

  before do
    stub_const(
      'Throttle::THROTTLE_CONFIG',
      {
        throttle_type => { max_attempts: max_attempts, attempt_window: attempt_window },
      }.with_indifferent_access.freeze,
    )
  end

  describe '.for' do
    context 'when target is a user' do
      let(:user) { create(:user) }
      subject(:for_target) { DatabaseThrottle.for(user: user, throttle_type: throttle_type) }

      context 'throttle does not exist yet' do
        it 'creates a new throttle row' do
          expect { for_target }.to change { DatabaseThrottle.count }.by(1)
        end
      end

      context 'throttle already exists' do
        let!(:existing) { create(:database_throttle, user: user, throttle_type: throttle_type) }

        it 'does not create a new throttle row' do
          expect { for_target }.to_not change { DatabaseThrottle.count }

          expect(for_target).to eq(existing)
        end
      end
    end

    context 'when target is a string' do
      let(:target) { Digest::SHA256.hexdigest(SecureRandom.hex) }
      subject(:for_target) { DatabaseThrottle.for(target: target, throttle_type: throttle_type) }

      context 'throttle does not exist yet' do
        it 'creates a new throttle row' do
          expect { for_target }.to change { DatabaseThrottle.count }.by(1)
        end
      end

      context 'throttle already exists' do
        let!(:existing) { create(:database_throttle, target: target, throttle_type: throttle_type) }

        it 'does not create a new throttle row' do
          expect { for_target }.to_not change { DatabaseThrottle.count }

          expect(for_target).to eq(existing)
        end
      end

      context 'target is not actually a string' do
        let(:target) { create(:user).id }

        it 'raises an error' do
          expect { for_target }.to raise_error(ArgumentError)
        end
      end
    end

    context 'when target and user are missing' do
      it 'throws an error' do
        expect { DatabaseThrottle.for(throttle_type: throttle_type) }.
          to raise_error(/Throttle must have a user or a target/)
      end
    end
  end

  describe '#increment' do
    subject(:throttle) { DatabaseThrottle.for(target: 'aaa', throttle_type: :idv_doc_auth) }

    it 'increments attempts' do
      expect { throttle.increment }.to change { throttle.reload.attempts }.by(1)
    end
  end

  describe '#throttled?' do
    let(:user) { create(:user) }
    let(:throttle_type) { :idv_doc_auth }
    let(:throttle) { DatabaseThrottle.all.first }
    let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
    let(:attempt_window_in_minutes) { IdentityConfig.store.doc_auth_attempt_window_in_minutes }

    subject(:throttle) { DatabaseThrottle.for(user: user, throttle_type: throttle_type) }

    it 'returns true if throttled' do
      create(
        :database_throttle,
        user: user,
        throttle_type: throttle_type,
        attempts: max_attempts,
        attempted_at: Time.zone.now,
      )

      expect(throttle.throttled?).to eq(true)
    end

    it 'returns false if the attempts < max_attempts' do
      create(
        :database_throttle,
        user: user,
        throttle_type: throttle_type,
        attempts: max_attempts - 1,
        attempted_at: Time.zone.now,
      )

      expect(throttle.throttled?).to eq(false)
    end

    it 'returns false if the attempts <= max_attempts but the window is expired' do
      create(
        :database_throttle,
        user: user,
        throttle_type: throttle_type,
        attempts: max_attempts,
        attempted_at: Time.zone.now - attempt_window_in_minutes.minutes,
      )

      expect(throttle.throttled?).to eq(false)
    end
  end

  describe '#throttled_else_increment?' do
    subject(:throttle) { DatabaseThrottle.for(target: 'aaaa', throttle_type: :idv_doc_auth) }

    context 'throttle has hit limit' do
      before do
        throttle.update(
          attempts: IdentityConfig.store.doc_auth_max_attempts + 1,
          attempted_at: Time.zone.now,
        )
      end

      it 'is true' do
        expect(throttle.throttled_else_increment?).to eq(true)
      end
    end

    context 'throttle has not hit limit' do
      it 'is false' do
        expect(throttle.throttled_else_increment?).to eq(false)
      end

      it 'increments the throttle' do
        expect { throttle.throttled_else_increment? }.to change { throttle.reload.attempts }.by(1)
      end
    end
  end

  describe '#expires_at' do
    around do |ex|
      freeze_time { ex.run }
    end

    let(:attempted_at) { nil }
    let(:throttle) { create(:database_throttle, user: create(:user), throttle_type: throttle_type) }

    subject(:expires_at) { throttle.tap { |t| t.update(attempted_at: attempted_at) }.expires_at }

    context 'without having attempted' do
      let(:attempted_at) { nil }

      it 'returns current time' do
        expect(expires_at).to eq(Time.zone.now)
      end
    end

    context 'with expired throttle' do
      let(:attempted_at) { Time.zone.now - (attempt_window + 1).minutes }

      it 'returns expiration time' do
        expect(expires_at).to eq(Time.zone.now - 1.minute)
      end
    end

    context 'with active throttle' do
      let(:attempted_at) { Time.zone.now - (attempt_window - 1).minutes }

      it 'returns expiration time' do
        expect(expires_at).to eq(Time.zone.now + 1.minute)
      end
    end
  end

  describe '#reset' do
    let(:user) { create(:user) }
    let(:subject) { described_class }

    subject(:throttle) { DatabaseThrottle.for(user: user, throttle_type: throttle_type) }

    it 'resets attempt count to 0' do
      create(
        :database_throttle,
        user: user,
        throttle_type: throttle_type,
        attempts: max_attempts,
        attempted_at: Time.zone.now,
      )

      expect { throttle.reset }.to change { throttle.reload.attempts }.to(0)
    end
  end
end
