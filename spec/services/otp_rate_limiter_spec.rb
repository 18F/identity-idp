require 'rails_helper'

RSpec.describe OtpRateLimiter do
  let(:current_user) { build(:user, :with_phone) }
  let(:phone) { MfaContext.new(current_user).phone_configurations.first.phone }
  subject(:otp_rate_limiter) do
    OtpRateLimiter.new(phone: phone, user: current_user, phone_confirmed: false)
  end
  subject(:otp_rate_limiter_confirmed) do
    OtpRateLimiter.new(phone: phone, user: current_user, phone_confirmed: true)
  end
  let(:phone_fingerprint) { Pii::Fingerprinter.fingerprint(phone) }
  let(:rate_limited_phone) do
    OtpRequestsTracker.find_by(phone_fingerprint: phone_fingerprint, phone_confirmed: false)
  end

  describe '#exceeded_otp_send_limit?' do
    it 'is false by default' do
      expect(otp_rate_limiter.exceeded_otp_send_limit?).to eq(false)
    end

    it 'is true after maxretry_times attemps +1 in findtime minutes' do
      expect(otp_rate_limiter.exceeded_otp_send_limit?).to eq(false)

      (IdentityConfig.store.otp_delivery_blocklist_maxretry + 1).times do
        otp_rate_limiter.increment
      end

      expect(otp_rate_limiter.exceeded_otp_send_limit?).to eq(true)
    end

    it 'tracks verified phones separately. limiting one does not limit the other' do
      expect(otp_rate_limiter.exceeded_otp_send_limit?).to eq(false)

      (IdentityConfig.store.otp_delivery_blocklist_maxretry + 1).times do
        otp_rate_limiter.increment
      end

      expect(otp_rate_limiter.exceeded_otp_send_limit?).to eq(true)
      expect(otp_rate_limiter_confirmed.exceeded_otp_send_limit?).to eq(false)
    end
  end

  describe '#increment' do
    it 'updates otp_last_sent_at' do
      tracker = OtpRequestsTracker.find_or_create_with_phone_and_confirmed(
        phone,
        false,
      )
      otp_rate_limiter.increment
      old_otp_last_sent_at = tracker.reload.otp_last_sent_at
      otp_rate_limiter.increment
      new_otp_last_sent_at = tracker.reload.otp_last_sent_at

      expect(new_otp_last_sent_at).to be > old_otp_last_sent_at
    end

    it 'increments the otp_send_count' do
      otp_rate_limiter.increment

      expect { otp_rate_limiter.increment }.
        to change { rate_limited_phone.reload.otp_send_count }.from(1).to(2)
    end
  end

  describe '#lock_out_user' do
    before do
      otp_rate_limiter.increment
      rate_limited_phone.otp_last_sent_at = 5.minutes.ago
      rate_limited_phone.otp_send_count = 0
    end

    it 'sets the second_factor_locked_at' do
      expect(current_user.second_factor_locked_at).to be_nil

      otp_rate_limiter.lock_out_user

      expect(current_user.second_factor_locked_at).to be_within(1.second).of(Time.zone.now)
    end
  end
end
