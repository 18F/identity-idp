require 'rails_helper'

RSpec.describe RecaptchaEnterpriseForm do
  let(:score_threshold) { 0.2 }
  let(:analytics) { FakeAnalytics.new }
  let(:extra_analytics_properties) { {} }
  let(:recaptcha_action) { 'example_action' }
  let(:recaptcha_enterprise_api_key) { 'recaptcha_enterprise_api_key' }
  let(:recaptcha_enterprise_project_id) { 'project_id' }
  let(:recaptcha_site_key) { 'recaptcha_site_key' }
  let(:assessment_url) do
    format(
      '%{base_endpoint}/%{project_id}/assessments?key=%{api_key}',
      base_endpoint: described_class::BASE_VERIFICATION_ENDPOINT,
      project_id: recaptcha_enterprise_project_id,
      api_key: recaptcha_enterprise_api_key,
    )
  end

  subject(:form) do
    described_class.new(
      recaptcha_action:,
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
    allow(IdentityConfig.store).to receive(:recaptcha_site_key).
      and_return(recaptcha_site_key)
  end

  describe '#exempt?' do
    subject(:exempt) { form.exempt? }

    context 'with initialized score threshold of 0' do
      let(:score_threshold) { 0.0 }

      it { expect(exempt).to eq(true) }
    end

    context 'with initialized score threshold greater than 0' do
      let(:score_threshold) { 0.1 }

      it { expect(exempt).to eq(false) }
    end
  end

  describe '#submit' do
    let(:token) { nil }
    subject(:result) { form.submit(token) }

    context 'with exemption' do
      before do
        allow(form).to receive(:exempt?).and_return(true)
      end

      it 'is successful without assessment id' do
        response, assessment_id = result

        expect(response.to_h).to eq(success: true)
        expect(assessment_id).to be_nil
      end

      it 'does not log analytics' do
        result

        expect(analytics).not_to have_logged_event('reCAPTCHA verify result received')
      end
    end

    context 'with missing token' do
      let(:token) { nil }

      it 'is unsuccessful with nil assessment id and error for blank token' do
        response, assessment_id = result

        expect(response.to_h).to eq(
          success: false,
          error_details: { recaptcha_token: { blank: true } },
        )
        expect(assessment_id).to be_nil
      end

      it 'does not log analytics' do
        result

        expect(analytics).not_to have_logged_event('reCAPTCHA verify result received')
      end
    end

    context 'with blank token' do
      let(:token) { '' }

      it 'is unsuccessful with nil assessment id and error for blank token' do
        response, assessment_id = result

        expect(response.to_h).to eq(
          success: false,
          error_details: { recaptcha_token: { blank: true } },
        )
        expect(assessment_id).to be_nil
      end

      it 'does not log analytics' do
        result

        expect(analytics).not_to have_logged_event('reCAPTCHA verify result received')
      end
    end

    context 'with unsuccessful response from validation service' do
      let(:token) { 'token' }
      let(:name) { 'projects/project-id/assessments/assessment-id' }

      before do
        stub_recaptcha_response(
          body: {
            tokenProperties: { valid: false, action: recaptcha_action, invalidReason: 'EXPIRED' },
            event: {},
            name:,
          },
          action: recaptcha_action,
          token:,
        )
      end

      it 'is unsuccessful with assessment id and error for invalid token' do
        response, assessment_id = result

        expect(response.to_h).to eq(
          success: false,
          error_details: { recaptcha_token: { invalid: true } },
        )
        expect(assessment_id).to eq(name)
      end

      it 'logs analytics of the body' do
        result

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            success: false,
            score: nil,
            errors: [],
            reasons: ['EXPIRED'],
            assessment_id: name,
          },
          evaluated_as_valid: false,
          score_threshold: score_threshold,
          form_class: 'RecaptchaEnterpriseForm',
          recaptcha_action:,
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
          action: recaptcha_action,
          token:,
        )
      end

      it 'is successful with nil assessment id' do
        response, assessment_id = result

        expect(response.to_h).to eq(success: true)
        expect(assessment_id).to be_nil
      end

      it 'logs analytics of the body' do
        result

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            success: false,
            assessment_id: nil,
            score: nil,
            errors: ['INVALID_ARGUMENT'],
            reasons: [],
          },
          evaluated_as_valid: true,
          score_threshold: score_threshold,
          form_class: 'RecaptchaEnterpriseForm',
          recaptcha_action:,
        )
      end
    end

    context 'with connection error' do
      let(:token) { 'token' }

      before do
        stub_request(:post, assessment_url).to_timeout
      end

      it 'is successful with nil assessment id' do
        response, assessment_id = result

        expect(response.to_h).to eq(success: true)
        expect(assessment_id).to be_nil
      end

      it 'logs analytics of the body' do
        result

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          evaluated_as_valid: true,
          score_threshold: score_threshold,
          form_class: 'RecaptchaEnterpriseForm',
          exception_class: 'Faraday::ConnectionFailed',
          recaptcha_action:,
        )
      end
    end

    context 'with failing score from validation service' do
      let(:token) { 'token' }
      let(:name) { 'projects/project-id/assessments/assessment-id' }
      let(:score) { score_threshold - 0.1 }

      before do
        stub_recaptcha_response(
          body: {
            tokenProperties: { valid: true, action: recaptcha_action },
            riskAnalysis: { score:, reasons: ['AUTOMATION'] },
            event: {},
            name:,
          },
          action: recaptcha_action,
          token:,
        )
      end

      it 'is unsuccessful with assesment id and error for invalid token' do
        response, assessment_id = result

        expect(response.to_h).to eq(
          success: false,
          error_details: { recaptcha_token: { invalid: true } },
        )
        expect(assessment_id).to eq(name)
      end

      it 'logs analytics of the body' do
        result

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            success: true,
            score:,
            reasons: ['AUTOMATION'],
            errors: [],
            assessment_id: name,
          },
          evaluated_as_valid: false,
          score_threshold: score_threshold,
          form_class: 'RecaptchaEnterpriseForm',
          recaptcha_action:,
        )
      end

      context 'with low confidence score as one of the reasons for failure' do
        before do
          stub_recaptcha_response(
            body: {
              tokenProperties: { valid: true, action: recaptcha_action },
              riskAnalysis: { score:, reasons: ['LOW_CONFIDENCE_SCORE'] },
              event: {},
              name:,
            },
            action: recaptcha_action,
            token:,
          )
        end

        it 'is successful with assessment id' do
          response, assessment_id = result

          expect(response.to_h).to eq(success: true)
          expect(assessment_id).to eq(name)
        end

        it 'logs analytics of the body' do
          result

          expect(analytics).to have_logged_event(
            'reCAPTCHA verify result received',
            recaptcha_result: {
              success: true,
              score:,
              reasons: ['LOW_CONFIDENCE_SCORE'],
              errors: [],
              assessment_id: name,
            },
            evaluated_as_valid: true,
            score_threshold: score_threshold,
            form_class: 'RecaptchaEnterpriseForm',
            recaptcha_action:,
          )
        end
      end
    end

    context 'with successful score from validation service' do
      let(:token) { 'token' }
      let(:name) { 'projects/project-id/assessments/assessment-id' }
      let(:score) { score_threshold + 0.1 }

      around do |example|
        stubbed_request = stub_recaptcha_response(
          body: {
            tokenProperties: { valid: true, action: recaptcha_action },
            riskAnalysis: { score:, reasons: ['LOW_CONFIDENCE'] },
            event: {},
            name:,
          },
          action: recaptcha_action,
          token:,
        )
        example.run
        expect(stubbed_request).to have_been_made.once
      end

      it 'is successful with assessment id' do
        response, assessment_id = result

        expect(response.to_h).to eq(success: true)
        expect(assessment_id).to eq(name)
      end

      it 'logs analytics of the body' do
        result

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            success: true,
            score:,
            reasons: ['LOW_CONFIDENCE'],
            errors: [],
            assessment_id: name,
          },
          evaluated_as_valid: true,
          score_threshold: score_threshold,
          form_class: 'RecaptchaEnterpriseForm',
          recaptcha_action:,
        )
      end

      context 'with action mismatch' do
        let(:name) { 'projects/project-id/assessments/assessment-id' }

        before do
          stub_recaptcha_response(
            body: {
              tokenProperties: { valid: true, action: 'wrong' },
              riskAnalysis: { score:, reasons: ['LOW_CONFIDENCE'] },
              event: {},
              name:,
            },
            action: recaptcha_action,
            token:,
          )
        end

        it 'is unsuccessful with assessment id and error for invalid token' do
          response, assessment_id = result

          expect(response.to_h).to eq(
            success: false,
            error_details: { recaptcha_token: { invalid: true } },
          )
          expect(assessment_id).to eq(name)
        end
      end

      context 'with extra analytics properties' do
        let(:extra_analytics_properties) { { extra: true } }

        it 'logs analytics of the body' do
          result

          expect(analytics).to have_logged_event(
            'reCAPTCHA verify result received',
            recaptcha_result: {
              success: true,
              score:,
              reasons: ['LOW_CONFIDENCE'],
              errors: [],
              assessment_id: name,
            },
            evaluated_as_valid: true,
            score_threshold: score_threshold,
            form_class: 'RecaptchaEnterpriseForm',
            recaptcha_action:,
            extra: true,
          )
        end
      end

      context 'without analytics' do
        let(:analytics) { nil }

        it 'validates gracefully without analytics logging' do
          result
        end
      end
    end
  end

  def stub_recaptcha_response(body:, action:, site_key: recaptcha_site_key, token: nil)
    stub_request(:post, assessment_url).
      with do |req|
        req.body == { event: { token:, siteKey: site_key, expectedAction: action } }.to_json
      end.
      to_return(headers: { 'Content-Type': 'application/json' }, body: body.to_json)
  end
end
