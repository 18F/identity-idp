require 'rails_helper'

RSpec.describe RecaptchaEnterpriseValidator do
  let(:score_threshold) { 0.2 }
  let(:analytics) { FakeAnalytics.new }
  let(:extra_analytics_properties) { {} }
  let(:action) { 'example_action' }
  let(:recaptcha_enterprise_api_key) { 'recaptcha_enterprise_api_key' }
  let(:recaptcha_enterprise_project_id) { 'project_id' }
  let(:recaptcha_site_key_v3) { 'recaptcha_site_key_v3' }
  let(:assessment_url) do
    format(
      '%{base_endpoint}/%{project_id}/assessments?key=%{api_key}',
      base_endpoint: described_class::BASE_VERIFICATION_ENDPOINT,
      project_id: recaptcha_enterprise_project_id,
      api_key: recaptcha_enterprise_api_key,
    )
  end

  subject(:validator) do
    described_class.new(
      recaptcha_action: action,
      score_threshold:,
      analytics:,
      extra_analytics_properties:,
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:recaptcha_enterprise_project_id).
      and_return(recaptcha_enterprise_project_id)
    allow(IdentityConfig.store).to receive(:recaptcha_enterprise_api_key).
      and_return(recaptcha_enterprise_api_key)
    allow(IdentityConfig.store).to receive(:recaptcha_site_key_v3).
      and_return(recaptcha_site_key_v3)
  end

  describe '#exempt?' do
    subject(:exempt) { validator.exempt? }

    context 'with initialized score threshold of 0' do
      let(:score_threshold) { 0.0 }

      it { expect(exempt).to eq(true) }
    end

    context 'with initialized score threshold greater than 0' do
      let(:score_threshold) { 0.1 }

      it { expect(exempt).to eq(false) }
    end
  end

  describe '#valid?' do
    let(:token) { nil }
    subject(:valid) { validator.valid?(token) }

    context 'with exemption' do
      before do
        allow(validator).to receive(:exempt?).and_return(true)
      end

      it { expect(valid).to eq(true) }

      it 'does not log analytics' do
        valid

        expect(analytics).not_to have_logged_event('reCAPTCHA verify result received')
      end
    end

    context 'with missing token' do
      let(:token) { nil }

      it { expect(valid).to eq(false) }

      it 'does not log analytics' do
        valid

        expect(analytics).not_to have_logged_event('reCAPTCHA verify result received')
      end
    end

    context 'with blank token' do
      let(:token) { '' }

      it { expect(valid).to eq(false) }

      it 'does not log analytics' do
        valid

        expect(analytics).not_to have_logged_event('reCAPTCHA verify result received')
      end
    end

    context 'with unsuccessful response from validation service' do
      let(:token) { 'token' }

      before do
        stub_recaptcha_response(
          body: {
            tokenProperties: { valid: false, action:, invalidReason: 'EXPIRED' },
            event: {},
          },
          action:,
          token:,
        )
      end

      it { expect(valid).to eq(false) }

      it 'logs analytics of the body' do
        valid

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            success: false,
            score: nil,
            errors: [],
            reasons: ['EXPIRED'],
          },
          evaluated_as_valid: false,
          score_threshold: score_threshold,
          recaptcha_version: 3,
          validator_class: 'RecaptchaEnterpriseValidator',
        )
      end
    end

    context 'with unsuccessful response due to misconfiguration' do
      let(:token) { 'token' }

      before do
        stub_recaptcha_response(
          body: {
            error: { code: 400, status: 'INVALID_ARGUMENT' },
          },
          action:,
          token:,
        )
      end

      it { expect(valid).to eq(true) }

      it 'logs analytics of the body' do
        valid

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            success: false,
            score: nil,
            errors: ['INVALID_ARGUMENT'],
            reasons: [],
          },
          evaluated_as_valid: true,
          score_threshold: score_threshold,
          recaptcha_version: 3,
          validator_class: 'RecaptchaEnterpriseValidator',
        )
      end
    end

    context 'with connection error' do
      let(:token) { 'token' }

      before do
        stub_request(:post, assessment_url).to_timeout
      end

      it { expect(valid).to eq(true) }

      it 'logs analytics of the body' do
        valid

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          evaluated_as_valid: true,
          score_threshold: score_threshold,
          recaptcha_version: 3,
          validator_class: 'RecaptchaEnterpriseValidator',
          exception_class: 'Faraday::ConnectionFailed',
        )
      end
    end

    context 'with failing score from validation service' do
      let(:token) { 'token' }
      let(:score) { score_threshold - 0.1 }

      before do
        stub_recaptcha_response(
          body: {
            tokenProperties: { valid: true, action: },
            riskAnalysis: { score:, reasons: ['AUTOMATION'] },
            event: {},
          },
          action:,
          token:,
        )
      end

      it { expect(valid).to eq(false) }

      it 'logs analytics of the body' do
        valid

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            success: true,
            score:,
            reasons: ['AUTOMATION'],
            errors: [],
          },
          evaluated_as_valid: false,
          score_threshold: score_threshold,
          recaptcha_version: 3,
          validator_class: 'RecaptchaEnterpriseValidator',
        )
      end
    end

    context 'with successful score from validation service' do
      let(:token) { 'token' }
      let(:score) { score_threshold + 0.1 }

      before do
        stub_recaptcha_response(
          body: {
            tokenProperties: { valid: true, action: },
            riskAnalysis: { score:, reasons: ['LOW_CONFIDENCE'] },
            event: {},
          },
          action:,
          token:,
        )
      end

      it { expect(valid).to eq(true) }

      it 'logs analytics of the body' do
        valid

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            success: true,
            score:,
            reasons: ['LOW_CONFIDENCE'],
            errors: [],
          },
          evaluated_as_valid: true,
          score_threshold: score_threshold,
          recaptcha_version: 3,
          validator_class: 'RecaptchaEnterpriseValidator',
        )
      end

      context 'with action mismatch' do
        before do
          stub_recaptcha_response(
            body: {
              tokenProperties: { valid: true, action: 'wrong' },
              riskAnalysis: { score:, reasons: ['LOW_CONFIDENCE'] },
              event: {},
            },
            action:,
            token:,
          )
        end

        it { expect(valid).to eq(false) }
      end

      context 'with extra analytics properties' do
        let(:extra_analytics_properties) { { extra: true } }

        it 'logs analytics of the body' do
          valid

          expect(analytics).to have_logged_event(
            'reCAPTCHA verify result received',
            recaptcha_result: {
              success: true,
              score:,
              reasons: ['LOW_CONFIDENCE'],
              errors: [],
            },
            evaluated_as_valid: true,
            score_threshold: score_threshold,
            recaptcha_version: 3,
            validator_class: 'RecaptchaEnterpriseValidator',
            extra: true,
          )
        end
      end

      context 'without analytics' do
        let(:analytics) { nil }

        it 'validates gracefully without analytics logging' do
          valid
        end
      end
    end
  end

  def stub_recaptcha_response(body:, action:, site_key: recaptcha_site_key_v3, token: nil)
    stub_request(:post, assessment_url).
      with do |req|
        req.body == { event: { token:, siteKey: site_key, expectedAction: action } }.to_json
      end.
      to_return(headers: { 'Content-Type': 'application/json' }, body: body.to_json)
  end
end
