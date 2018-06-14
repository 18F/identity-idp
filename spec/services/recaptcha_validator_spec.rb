require 'rails_helper'

describe RecaptchaValidator do
  let(:key_name) { 'resource#new' }
  let(:analytics) do
    {
      recaptcha_valid: true,
      recaptcha_present: true,
      recaptcha_enabled: true,
    }
  end

  describe '#valid' do
    context 'when disabled by configuration' do
      it 'is always considered valid' do
        allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(false)
        recaptcha = described_class.new(key_name, false, true)

        expect(recaptcha.valid?).to be(true)
      end
    end

    context 'when enabled by configuration' do
      it 'is invalid when reCAPTCHA fails' do
        allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(true)
        recaptcha = described_class.new(key_name, false, true)

        expect(recaptcha.valid?).to be(false)
      end

      it 'is valid when reCAPTCHA succeeds' do
        allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(true)
        recaptcha = described_class.new(key_name, true, true)

        expect(recaptcha.valid?).to be(true)
      end
    end
  end

  it 'returns extra analytics attributes' do
    allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(true)
    recaptcha = described_class.new(key_name, true, true)

    expect(recaptcha.extra_analytics_attributes).to eq(analytics)
  end
end
