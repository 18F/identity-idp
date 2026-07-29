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

      expect(described_class.first_with_otp(otp)).to eq(good_confirmation_code)
    end

    it 'normalizes the entered otp before searching' do
      confirmation_code = create(
        :gpo_confirmation_code,
        otp_fingerprint: Pii::Fingerprinter.fingerprint('ABC000'),
      )

      expect(described_class.first_with_otp('abcooo')).to eq(confirmation_code)
    end

    it 'returns nil if no record matches the OTP' do
      create(:gpo_confirmation_code)

      expect(described_class.first_with_otp(otp)).to be_nil
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

    context 'when the state is nil (legacy record)' do
      it 'falls back to the non-contiguous/default max days' do
        confirmation_code = build(
          :gpo_confirmation_code,
          state: nil,
          code_sent_at: (IdentityConfig.store.usps_confirmation_max_days - 1).days.ago,
        )

        expect(confirmation_code.expired?).to eq(false)
      end
    end

    context 'when the state is a contiguous US state' do
      it 'expires after usps_confirmation_max_days_contiguous_states days' do
        confirmation_code = build(
          :gpo_confirmation_code,
          state: 'VA',
          code_sent_at: (IdentityConfig.store.usps_confirmation_max_days_contiguous_states -
            1).days.ago,
        )

        expect(confirmation_code.expired?).to eq(false)

        confirmation_code.code_sent_at =
          (IdentityConfig.store.usps_confirmation_max_days_contiguous_states + 1).days.ago
        expect(confirmation_code.expired?).to eq(true)
      end
    end

    context 'when the state is a non-contiguous state or territory' do
      it 'expires after usps_confirmation_max_days days' do
        confirmation_code = build(
          :gpo_confirmation_code,
          state: 'PR',
          code_sent_at: (IdentityConfig.store.usps_confirmation_max_days - 1).days.ago,
        )

        expect(confirmation_code.expired?).to eq(false)

        confirmation_code.code_sent_at =
          (IdentityConfig.store.usps_confirmation_max_days + 1).days.ago
        expect(confirmation_code.expired?).to eq(true)
      end
    end
  end

  describe '#max_days' do
    it 'delegates to GpoConfirmationMaxDaysCalculator' do
      confirmation_code = build(:gpo_confirmation_code, state: 'CA')

      expect(GpoConfirmationMaxDaysCalculator).to receive(:max_days_for_state).with('CA')
      confirmation_code.max_days
    end
  end
end
