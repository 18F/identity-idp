require 'rails_helper'

RSpec.describe UspsConfirmationCode do
  let(:otp) { 'ABC123' }
  let(:profile) { build(:profile) }

  describe '.first_with_otp' do
    it 'return the record with the matching OTP' do
      create(:usps_confirmation_code)
      good_confirmation_code = create(
        :usps_confirmation_code,
        otp_fingerprint: Pii::Fingerprinter.fingerprint(otp)
      )

      expect(described_class.first_with_otp(otp)).to eq(good_confirmation_code)
    end

    it 'normalizes the entered otp before searching' do
      confirmation_code = create(
        :usps_confirmation_code,
        otp_fingerprint: Pii::Fingerprinter.fingerprint('ABC000')
      )

      expect(described_class.first_with_otp('abcooo')).to eq(confirmation_code)
    end

    it 'returns nil if no record matches the OTP' do
      create(:usps_confirmation_code)

      expect(described_class.first_with_otp(otp)).to be_nil
    end
  end

  describe '#expired?' do
    it 'returns false for a valid otp' do
      confirmation_code = build(
        :usps_confirmation_code,
        code_sent_at: Time.zone.now
      )

      expect(confirmation_code.expired?).to eq(false)
    end

    it 'returns true for an expired otp' do
      confirmation_code = build(
        :usps_confirmation_code,
        code_sent_at: (Figaro.env.usps_confirmation_max_days.to_i + 1).days.ago
      )

      expect(confirmation_code.expired?).to eq(true)
    end
  end
end
