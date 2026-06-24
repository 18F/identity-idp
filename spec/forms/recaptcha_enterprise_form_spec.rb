require 'rails_helper'

RSpec.describe RecaptchaEnterpriseForm do
  let(:score_threshold) { 0.2 }
  let(:analytics) { FakeAnalytics.new }
  let(:extra_analytics_properties) { {} }
  let(:recaptcha_action) { 'example_action' }

  subject(:form) do
    described_class.new(
      recaptcha_action:,
      score_threshold:,
      analytics:,
      extra_analytics_properties:,
    )
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

    context 'with an unsuccessful response from RecaptchaService' do
      let(:token) { 'TOKEN' }
      let(:recaptcha_action) { 'ACTION' }
      let(:recaptcha_service) { instance_double(RecaptchaService) }

      before do
        allow(RecaptchaService).to receive(:new).and_return(recaptcha_service)
        allow(recaptcha_service).to receive(:create_assessment)
          .with(recaptcha_token: token, recaptcha_action:)
          .and_return(RecaptchaService::RecaptchaResult.new(success: false, reasons: ['EXPIRED']))
      end

      it 'is unsuccessful with assessment id and error for invalid token' do
        response, _ = result

        expect(response.to_h).to eq(
          success: false,
          error_details: { recaptcha_token: { invalid: true } },
        )
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
            assessment_id: nil,
          },
          evaluated_as_valid: false,
          score_threshold: score_threshold,
          form_class: 'RecaptchaEnterpriseForm',
          recaptcha_action:,
        )
      end
    end

    context 'with failing score from validation service' do
      let(:token) { 'token' }
      let(:name) { 'projects/project-id/assessments/assessment-id' }
      let(:score) { score_threshold - 0.1 }
      let(:recaptcha_action) { 'ACTION' }
      let(:recaptcha_service) { instance_double(RecaptchaService) }
      let(:risk_analysis_reason) { 'AUTOMATION' }

      before do
        allow(RecaptchaService).to receive(:new).and_return(recaptcha_service)
        allow(recaptcha_service).to receive(:create_assessment)
          .with(recaptcha_token: token, recaptcha_action:)
          .and_return(RecaptchaService::RecaptchaResult.new(
            success: true,
            reasons: [risk_analysis_reason],
            assessment_id: name,
            score:,
          ))
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
            success: true,
            score:,
            reasons: [risk_analysis_reason],
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
        let(:risk_analysis_reason) { 'LOW_CONFIDENCE_SCORE' }

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

    context 'with successful score from recaptcha service' do
      let(:token) { 'token' }
      let(:name) { 'projects/project-id/assessments/assessment-id' }
      let(:score) { score_threshold + 0.1 }
      let(:recaptcha_action) { 'ACTION' }
      let(:recaptcha_service) { instance_double(RecaptchaService) }

      before do
        allow(RecaptchaService).to receive(:new).and_return(recaptcha_service)
        allow(recaptcha_service).to receive(:create_assessment)
          .with(recaptcha_token: token, recaptcha_action:)
          .and_return(RecaptchaService::RecaptchaResult.new(
            success: true,
            reasons: ['LOW_CONFIDENCE'],
            assessment_id: name,
            score:,
          ))
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

      context 'with extra analytics properties' do
        let(:extra_analytics_properties) { { phone_country_code: true } }

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
            phone_country_code: true,
          )
        end
      end
    end
  end

  def stub_recaptcha_response(body:, action:, site_key: recaptcha_site_key, token: nil)
    stub_request(:post, assessment_url)
      .with do |req|
        req.body == { event: { token:, siteKey: site_key, expectedAction: action } }.to_json
      end
      .to_return(headers: { 'Content-Type': 'application/json' }, body: body.to_json)
  end
end
