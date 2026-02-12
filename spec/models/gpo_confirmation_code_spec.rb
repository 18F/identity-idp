require 'rails_helper'

RSpec.describe GpoConfirmationCode do
  let(:otp) { 'ABC123' }
  let(:profile) { build(:profile) }

  describe '.first_with_otp' do
    it 'return the record with the matching OTP' do
      create(:gpo_confirmation_code)
      good_confirmation_code = create(
        :gpo_confirmation_code,
        otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
      )

      expect(GpoConfirmationCode.first_with_otp(otp)).to eq(good_confirmation_code)
    end

    it 'normalizes the entered otp before searching' do
      confirmation_code = create(
        :gpo_confirmation_code,
        otp_fingerprint: Pii::Fingerprinter.fingerprint('ABC000'),
      )

      expect(GpoConfirmationCode.first_with_otp('abcooo')).to eq(confirmation_code)
    end

    it 'returns nil if no record matches the OTP' do
      create(:gpo_confirmation_code)

      expect(GpoConfirmationCode.first_with_otp(otp)).to be_nil
    end
  end

  describe '#expired?' do
    it 'returns false for a valid otp' do
      confirmation_code = build(
        :gpo_confirmation_code,
        code_sent_at: Time.zone.now,
      )

      expect(confirmation_code.expired?).to eq(false)
    end

    it 'returns true for an expired otp' do
      confirmation_code = build(
        :gpo_confirmation_code,
        code_sent_at: (IdentityConfig.store.usps_confirmation_max_days + 1).days.ago,
      )

      expect(confirmation_code.expired?).to eq(true)
    end
  end
end
