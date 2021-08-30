require 'rails_helper'

RSpec.describe Throttle do
  let(:throttle_type) { :idv_acuant }

  describe '.for' do
    context 'when target is a user' do
      let(:user) { create(:user) }
      subject(:for_target) { Throttle.for(user: user, throttle_type: throttle_type) }

      context 'throttle does not exist yet' do
        it 'creates a new throttle row' do
          expect { for_target }.to change { Throttle.count }.by(1)
        end
      end

      context 'throttle already exists' do
        let!(:existing) { create(:throttle, user: user, throttle_type: throttle_type) }

        it 'does not create a new throttle row' do
          expect { for_target }.to_not change { Throttle.count }

          expect(for_target).to eq(existing)
        end
      end
    end

    context 'when target is a string' do
      let(:target) { Digest::SHA256.hexdigest(SecureRandom.hex) }
      subject(:for_target) { Throttle.for(target: target, throttle_type: throttle_type) }

      context 'throttle does not exist yet' do
        it 'creates a new throttle row' do
          expect { for_target }.to change { Throttle.count }.by(1)
        end
      end

      context 'throttle already exists' do
        let!(:existing) { create(:throttle, target: target, throttle_type: throttle_type) }

        it 'does not create a new throttle row' do
          expect { for_target }.to_not change { Throttle.count }

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
        expect { Throttle.for(throttle_type: throttle_type) }.
          to raise_error(/Throttle must have a user or a target/)
      end
    end
  end

  describe '#increment' do
    subject(:throttle) { Throttle.for(target: 'aaa', throttle_type: :idv_acuant) }

    it 'increments attempts' do
      expect { throttle.increment }.to change { throttle.reload.attempts }.by(1)
    end
  end

  describe '#throttled?' do
    let(:user) { create(:user) }
    let(:throttle_type) { :idv_acuant }
    let(:throttle) { Throttle.all.first }
    let(:max_attempts) { IdentityConfig.store.acuant_max_attempts }
    let(:attempt_window_in_minutes) { IdentityConfig.store.acuant_attempt_window_in_minutes }

    subject(:throttle) { Throttle.for(user: user, throttle_type: throttle_type) }

    it 'returns true if throttled' do
      create(
        :throttle,
        user: user,
        throttle_type: throttle_type,
        attempts: max_attempts,
        attempted_at: Time.zone.now,
      )

      expect(throttle.throttled?).to eq(true)
    end

    it 'returns false if the attempts < max_attempts' do
      create(
        :throttle,
        user: user,
        throttle_type: throttle_type,
        attempts: max_attempts - 1,
        attempted_at: Time.zone.now,
      )

      expect(throttle.throttled?).to eq(false)
    end

    it 'returns false if the attempts <= max_attempts but the window is expired' do
      create(
        :throttle,
        user: user,
        throttle_type: throttle_type,
        attempts: max_attempts,
        attempted_at: Time.zone.now - attempt_window_in_minutes.minutes,
      )

      expect(throttle.throttled?).to eq(false)
    end
  end

  describe '#throttled_else_increment?' do
    subject(:throttle) { Throttle.for(target: 'aaaa', throttle_type: :idv_acuant) }

    context 'throttle has hit limit' do
      before do
        throttle.update(
          attempts: IdentityConfig.store.acuant_max_attempts + 1,
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

  describe '#reset' do
    let(:user) { create(:user) }
    let(:throttle_type) { :idv_acuant }
    let(:max_attempts) { 3 }
    let(:subject) { described_class }

    subject(:throttle) { Throttle.for(user: user, throttle_type: throttle_type) }

    it 'resets attempt count to 0' do
      create(
        :throttle,
        user: user,
        throttle_type: throttle_type,
        attempts: max_attempts,
        attempted_at: Time.zone.now,
      )

      expect { throttle.reset }.to change { throttle.reload.attempts }.to(0)
    end
  end
end
