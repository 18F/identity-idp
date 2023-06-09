require 'rails_helper'

RSpec.describe PhoneRecaptchaValidator do
  let(:country_score_overrides_config) { {} }
  let(:score_threshold_config) { 0.2 }
  let(:parsed_phone) { Phonelib.parse('+15135551234') }
  let(:recaptcha_version) { 3 }
  let(:analytics) { FakeAnalytics.new }
  subject(:validator) { described_class.new(parsed_phone:, recaptcha_version:, analytics:) }
  before do
    allow(IdentityConfig.store).to receive(:phone_recaptcha_country_score_overrides).
      and_return(country_score_overrides_config)
    allow(IdentityConfig.store).to receive(:phone_recaptcha_score_threshold).
      and_return(score_threshold_config)
  end

  it 'passes instance variables to validator' do
    recaptcha_validator = instance_double(RecaptchaValidator, valid?: true)
    expect(RecaptchaValidator).to receive(:new).
      with(
        score_threshold: score_threshold_config,
        analytics:,
        recaptcha_version:,
        recaptcha_action: described_class::RECAPTCHA_ACTION,
        extra_analytics_properties: {
          phone_country_code: parsed_phone.country,
        },
      ).
      and_return(recaptcha_validator)

    validator.valid?('token')
  end

  context 'with custom recaptcha validator class' do
    subject(:validator) do
      described_class.new(
        parsed_phone:,
        recaptcha_version:,
        analytics:,
        validator_class: RecaptchaMockValidator,
      )
    end

    it 'delegates to validator instance of the given class' do
      recaptcha_validator = instance_double(RecaptchaMockValidator, valid?: true)
      expect(RecaptchaMockValidator).to receive(:new).and_return(recaptcha_validator)
      expect(recaptcha_validator).to receive(:valid?)

      validator.valid?('token')
    end
  end

  describe '#valid?' do
    it 'is delegated to recaptcha validator' do
      recaptcha_validator = instance_double(RecaptchaValidator, valid?: true)
      expect(validator).to receive(:validator).and_return(recaptcha_validator)
      expect(recaptcha_validator).to receive(:valid?)

      validator.valid?('token')
    end
  end

  describe '#exempt?' do
    it 'is delegated to recaptcha validator' do
      recaptcha_validator = instance_double(RecaptchaValidator, exempt?: true)
      expect(validator).to receive(:validator).and_return(recaptcha_validator)
      expect(recaptcha_validator).to receive(:exempt?)

      validator.exempt?
    end
  end

  describe '.exempt_countries' do
    subject(:exempt_countries) { described_class.exempt_countries }

    it 'returns an array of exempt countries' do
      expect(exempt_countries).to eq([])
    end

    context 'with country overrides' do
      let(:country_score_overrides_config) { { US: 0.0, CA: 0.1 } }

      it 'returns an array of exempt countries' do
        expect(exempt_countries).to eq([:US])
      end
    end
  end

  describe '.country_score_overrides' do
    subject(:country_score_overrides) { described_class.country_score_overrides }

    it 'returns configured country score overrides' do
      expect(country_score_overrides).to eq(country_score_overrides_config)
    end
  end

  describe '#score_threshold' do
    subject(:score_threshold) { validator.score_threshold }

    context 'without country override' do
      it 'returns default score threshold configuration value' do
        expect(score_threshold).to eq(score_threshold_config)
      end
    end

    context 'with valid country override for phone' do
      let(:score_override) { 0.1 }
      let(:country_score_overrides_config) { { US: score_override } }

      it 'returns the override for the matching country' do
        expect(score_threshold).to eq(score_override)
      end
    end

    context 'with multiple valid country overrides for phone' do
      let(:min_score_override) { 0.1 }
      let(:country_score_overrides_config) { { US: min_score_override, CA: 0.9 } }

      before do
        allow(parsed_phone).to receive(:valid_countries).and_return(['US', 'CA', 'FR'])
      end

      it 'returns the minimum of overriding scores' do
        expect(score_threshold).to eq(min_score_override)
      end
    end
  end
end
