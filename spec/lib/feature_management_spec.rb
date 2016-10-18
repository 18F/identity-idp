require 'rails_helper'

describe 'FeatureManagement', type: :feature do
  describe '#prefill_otp_codes?' do
    context 'when SMS sending is disabled' do
      before { allow(FeatureManagement).to receive(:telephony_disabled?).and_return(true) }

      it 'returns true in development mode' do
        allow(Rails.env).to receive(:development?).and_return(true)

        expect(FeatureManagement.prefill_otp_codes?).to eq(true)
      end

      it 'returns false in non-development mode' do
        allow(Rails.env).to receive(:development?).and_return(false)

        expect(FeatureManagement.prefill_otp_codes?).to eq(false)
      end
    end

    context 'when SMS sending is enabled' do
      before { allow(FeatureManagement).to receive(:telephony_disabled?).and_return(false) }

      it 'returns false in development mode' do
        allow(Rails.env).to receive(:development?).and_return(true)

        expect(FeatureManagement.prefill_otp_codes?).to eq(false)
      end

      it 'returns false in non-development mode' do
        allow(Rails.env).to receive(:development?).and_return(false)

        expect(FeatureManagement.prefill_otp_codes?).to eq(false)
      end
    end
  end

  describe '#enable_i18n_mode?' do
    context 'when enabled' do
      before do
        allow(Figaro.env).to receive(:enable_i18n_mode).and_return('true')
      end

      it 'enables the feature' do
        expect(FeatureManagement.enable_i18n_mode?).to eq(true)
      end
    end

    context 'when disabled' do
      before do
        allow(Figaro.env).to receive(:enable_i18n_mode).and_return('false')
      end

      it 'disables the feature' do
        expect(FeatureManagement.enable_i18n_mode?).to eq(false)
      end
    end
  end

  describe '#use_kms?' do
    context 'when enabled' do
      before do
        allow(Figaro.env).to receive(:use_kms).and_return('true')
      end

      it 'enables the feature' do
        expect(FeatureManagement.use_kms?).to eq(true)
      end

      it 'throws exception when attempting to fetch PII signing key' do
        expect do
          Pii::KeyMaker.new
        end.to raise_error RuntimeError
      end
    end
  end
end
