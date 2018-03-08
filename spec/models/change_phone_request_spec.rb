require 'rails_helper'

describe ChangePhoneRequest do
  it { is_expected.to belong_to(:user) }

  let(:cpr) do
    ChangePhoneRequest.new
  end

  describe '#change_phone_link_expired?' do
    it 'returns true if reset device is disabled' do
      cpr.granted_at = Time.zone.now
      allow(Figaro.env).to receive(:reset_device_enabled).and_return('false')
      expect(cpr.change_phone_link_expired?).to eq(true)
    end

    it 'returns false if granted_at is not expired' do
      cpr.granted_at = Time.zone.now
      expect(cpr.change_phone_link_expired?).to eq(false)
    end

    it 'returns true if granted_at is expired' do
      cpr.granted_at = Time.zone.now - (Figaro.env.reset_device_valid_for_hours.to_i * 3600)
      expect(cpr.change_phone_link_expired?).to eq(true)
    end
  end

  describe '#change_phone_allowed?' do
    it 'returns true if security_answer_correct is correct and answered_at is not expired' do
      cpr.answered_at = Time.zone.now
      cpr.security_answer_correct = true
      expect(cpr.change_phone_allowed?).to eq(true)
    end

    it 'returns false if reset device is disabled' do
      cpr.answered_at = Time.zone.now
      cpr.security_answer_correct = true
      allow(Figaro.env).to receive(:reset_device_enabled).and_return('false')
      expect(cpr.change_phone_allowed?).to eq(false)
    end

    it 'returns false if security_answer_correct is not true' do
      cpr.answered_at = Time.zone.now
      cpr.security_answer_correct = false
      expect(cpr.change_phone_allowed?).to eq(false)
    end

    it 'returns false if answered_at is expired' do
      cpr.answered_at = Time.zone.now - (Figaro.env.reset_device_valid_for_hours.to_i * 3600)
      cpr.security_answer_correct = true
      expect(cpr.change_phone_allowed?).to eq(false)
    end
  end
end
