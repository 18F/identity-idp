require 'rails_helper'

RSpec.describe PhoneRecaptchaForm do
  let(:country_score_overrides_config) { {} }
  let(:score_threshold_config) { 0.2 }
  let(:parsed_phone) { Phonelib.parse('+15135551234') }
  let(:analytics) { FakeAnalytics.new }
  subject(:form) { described_class.new(parsed_phone:, analytics:) }
  before do
    allow(IdentityConfig.store).to receive(:phone_recaptcha_country_score_overrides)
      .and_return(country_score_overrides_config)
    allow(IdentityConfig.store).to receive(:phone_recaptcha_score_threshold)
      .and_return(score_threshold_config)
  end

  it 'passes instance variables to form' do
    recaptcha_form = instance_double(
      RecaptchaForm,
      submit: FormResponse.new(success: true),
    )
    expect(RecaptchaForm).to receive(:new)
      .with(
        score_threshold: score_threshold_config,
        analytics:,
        recaptcha_action: described_class::RECAPTCHA_ACTION,
        extra_analytics_properties: {
          phone_country_code: parsed_phone.country,
        },
      )
      .and_return(recaptcha_form)

    form.submit('token')
  end

  context 'with custom recaptcha form class' do
    subject(:form) do
      described_class.new(
        parsed_phone:,
        analytics:,
        form_class: RecaptchaMockForm,
      )
    end

    it 'delegates to form instance of the given class' do
      recaptcha_form = instance_double(
        RecaptchaForm,
        submit: FormResponse.new(success: true),
      )
      expect(RecaptchaMockForm).to receive(:new).and_return(recaptcha_form)
      expect(recaptcha_form).to receive(:submit)

      form.submit('token')
    end
  end

  describe '#submit' do
    it 'is delegated to recaptcha form' do
      recaptcha_form = instance_double(
        RecaptchaForm,
        submit: FormResponse.new(success: true),
      )
      expect(form).to receive(:form).and_return(recaptcha_form)
      expect(recaptcha_form).to receive(:submit)

      form.submit('token')
    end
  end

  describe '#errors' do
    it 'is delegated to recaptcha form' do
      recaptcha_form = instance_double(RecaptchaForm, errors: ActiveModel::Errors.new({}))
      expect(form).to receive(:form).and_return(recaptcha_form)
      expect(recaptcha_form).to receive(:errors)

      form.errors
    end
  end

  describe '.country_score_overrides' do
    subject(:country_score_overrides) { described_class.country_score_overrides }

    it 'returns configured country score overrides' do
      expect(country_score_overrides).to eq(country_score_overrides_config)
    end
  end

  describe '#score_threshold' do
    subject(:score_threshold) { form.score_threshold }

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
