require 'rails_helper'
require 'query_tracker'

RSpec.describe SignInRecaptchaForm do
  let(:user) { create(:user, :with_authenticated_device) }
  let(:score_threshold_config) { 0.2 }
  let(:analytics) { FakeAnalytics.new }
  let(:existing_device) { false }
  let(:ab_test_bucket) { :sign_in_recaptcha }
  let(:recaptcha_token) { 'token' }
  let(:score) { 1.0 }
  subject(:form) do
    described_class.new(
      existing_device:,
      ab_test_bucket:,
      form_class: RecaptchaMockForm,
      analytics:,
      score:,
    )
  end
  before do
    allow(IdentityConfig.store).to receive(:sign_in_recaptcha_score_threshold)
      .and_return(score_threshold_config)
  end

  it 'passes instance variables to form' do
    recaptcha_form = instance_double(
      RecaptchaMockForm,
      submit: FormResponse.new(success: true),
    )
    expect(RecaptchaMockForm).to receive(:new)
      .with(
        score_threshold: score_threshold_config,
        score:,
        analytics:,
        recaptcha_action: described_class::RECAPTCHA_ACTION,
      )
      .and_return(recaptcha_form)

    form.submit(recaptcha_token:)
  end

  context 'with custom recaptcha form class' do
    subject(:form) do
      described_class.new(
        existing_device:,
        ab_test_bucket:,
        analytics:,
        form_class: RecaptchaForm,
      )
    end

    it 'validates using form instance of the given class' do
      recaptcha_form = instance_double(
        RecaptchaForm,
        submit: FormResponse.new(success: true),
      )
      expect(RecaptchaForm).to receive(:new).and_return(recaptcha_form)
      expect(recaptcha_form).to receive(:submit)

      form.submit(recaptcha_token:)
    end
  end

  describe '#exempt?' do
    subject(:exempt?) { form.exempt? }

    it { is_expected.to eq(false) }

    context 'when not part of a/b test' do
      let(:ab_test_bucket) { nil }

      it { is_expected.to eq(true) }
    end

    context 'score threshold configured at zero' do
      let(:score_threshold_config) { 0.0 }

      it { is_expected.to eq(true) }

      it { expect(queries_database?).to eq(false) }
    end

    context 'existing device for user' do
      let(:existing_device) { true }

      it { is_expected.to eq(true) }
    end

    def queries_database?
      user
      QueryTracker.track { exempt? }.present?
    end
  end

  describe '#submit' do
    let(:recaptcha_form_success) { false }
    subject(:response) { form.submit(recaptcha_token:) }

    context 'recaptcha form validates as unsuccessful' do
      let(:score) { 0.0 }

      context 'existing device for user' do
        let(:existing_device) { true }

        it 'is successful' do
          expect(response.to_h).to eq(success: true)
        end
      end

      context 'when not part of a/b test' do
        let(:ab_test_bucket) { nil }

        it 'is successful' do
          expect(response.to_h).to eq(success: true)
        end
      end

      context 'new device for user' do
        it 'is unsuccessful with errors from recaptcha validation' do
          expect(response.to_h).to eq(
            success: false,
            error_details: { recaptcha_token: { invalid: true } },
          )
        end
      end
    end

    context 'recaptcha form validates as successful' do
      it 'is successful' do
        expect(response.to_h).to eq(success: true)
      end
    end
  end
end
