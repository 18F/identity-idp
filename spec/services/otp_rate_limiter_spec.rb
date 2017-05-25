require 'rails_helper'

RSpec.describe OtpRateLimiter do
  let(:current_user) { build(:user) }
  subject(:otp_rate_limiter) { OtpRateLimiter.new(current_user) }

  describe '#exceeded_otp_send_limit?' do
    it 'is false by default' do
      expect(otp_rate_limiter.exceeded_otp_send_limit?).to eq(false)
    end

    it 'is true after maxretry_times attemps in findtime minutes' do
      expect(otp_rate_limiter.exceeded_otp_send_limit?).to eq(false)

      Figaro.env.otp_delivery_blocklist_maxretry.to_i.times do
        otp_rate_limiter.increment
      end

      expect(otp_rate_limiter.exceeded_otp_send_limit?).to eq(true)
    end
  end

  describe '#increment' do
    it 'sets the otp_last_sent_at' do
      expect(current_user.otp_last_sent_at).to be_nil

      now = Time.zone.now
      otp_rate_limiter.increment

      expect(current_user.otp_last_sent_at.to_i).to eq(now.to_i)
    end

    it 'increments the otp_send_count' do
      expect { otp_rate_limiter.increment }.
        to change { current_user.otp_send_count }.from(0).to(1)
    end
  end

  describe '#lock_out_user' do
    before do
      current_user.otp_last_sent_at = 5.minutes.ago
      current_user.otp_send_count = 0
    end

    it 'resets otp_last_sent_at and otp_send_count' do
      otp_rate_limiter.lock_out_user

      expect(current_user.otp_last_sent_at).to be_nil
      expect(current_user.otp_send_count).to eq(0)
    end

    it 'sets the second_factor_locked_at' do
      expect(current_user.second_factor_locked_at).to be_nil

      otp_rate_limiter.lock_out_user

      expect(current_user.second_factor_locked_at.to_i).to eq(Time.zone.now.to_i)
    end
  end
end
