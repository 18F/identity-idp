require 'rails_helper'

RSpec.describe RecaptchaForm do
  let(:score_threshold) { 0.2 }
  let(:analytics) { FakeAnalytics.new }
  let(:extra_analytics_properties) { {} }
  let(:recaptcha_secret_key) { 'recaptcha_secret_key' }
  let(:recaptcha_action) { 'example_action' }

  subject(:form) do
    RecaptchaForm.new(score_threshold:, recaptcha_action:, analytics:, extra_analytics_properties:)
  end

  before do
    allow(IdentityConfig.store).to receive(:recaptcha_secret_key)
      .and_return(recaptcha_secret_key)
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

      it 'is successful' do
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

      it 'is unsuccessful with error for blank token' do
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

      it 'is unsuccessful with error for blank token' do
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

      before do
        stub_recaptcha_response(
          body: { success: false, 'error-codes': ['timeout-or-duplicate'] },
          token:,
        )
      end

      it 'is unsuccessful with error for invalid token' do
        response, assessment_id = result

        expect(response.to_h).to eq(
          success: false,
          error_details: { recaptcha_token: { invalid: true } },
        )
        expect(assessment_id).to be_nil
      end

      it 'logs analytics of the body' do
        result

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            assessment_id: nil,
            success: false,
            score: nil,
            reasons: ['timeout-or-duplicate'],
            errors: [],
          },
          evaluated_as_valid: false,
          score_threshold: score_threshold,
          form_class: 'RecaptchaForm',
          recaptcha_action:,
        )
      end

      context 'with unsuccessful response due to misconfiguration' do
        context 'with missing input secret' do
          before do
            stub_recaptcha_response(
              body: { success: false, 'error-codes': ['missing-input-secret'] },
              token:,
            )
          end

          it 'is successful' do
            response, assessment_id = result

            expect(response.to_h).to eq(success: true)
            expect(assessment_id).to be_nil
          end

          it 'logs analytics of the body' do
            result

            expect(analytics).to have_logged_event(
              'reCAPTCHA verify result received',
              recaptcha_result: {
                assessment_id: nil,
                success: false,
                score: nil,
                errors: ['missing-input-secret'],
                reasons: [],
              },
              evaluated_as_valid: true,
              score_threshold: score_threshold,
              form_class: 'RecaptchaForm',
              recaptcha_action:,
            )
          end
        end

        context 'with invalid input secret' do
          before do
            stub_recaptcha_response(
              body: { success: false, 'error-codes': ['invalid-input-secret'] },
              token:,
            )
          end

          it 'is successful' do
            response, assessment_id = result

            expect(response.to_h).to eq(success: true)
            expect(assessment_id).to be_nil
          end

          it 'logs analytics of the body' do
            result

            expect(analytics).to have_logged_event(
              'reCAPTCHA verify result received',
              recaptcha_result: {
                assessment_id: nil,
                success: false,
                score: nil,
                errors: ['invalid-input-secret'],
                reasons: [],
              },
              evaluated_as_valid: true,
              score_threshold: score_threshold,
              form_class: 'RecaptchaForm',
              recaptcha_action:,
            )
          end
        end
      end
    end

    context 'with connection error' do
      let(:token) { 'token' }

      before do
        stub_request(:post, RecaptchaForm::VERIFICATION_ENDPOINT).to_timeout
      end

      it 'is successful' do
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
          form_class: 'RecaptchaForm',
          exception_class: 'Faraday::ConnectionFailed',
          recaptcha_action:,
        )
      end
    end

    context 'with failing score from validation service' do
      let(:token) { 'token' }
      let(:score) { score_threshold - 0.1 }

      before do
        stub_recaptcha_response(body: { success: true, score: }, token:)
      end

      it 'is unsuccessful with error for invalid token' do
        response, assessment_id = result

        expect(response.to_h).to eq(
          success: false,
          error_details: { recaptcha_token: { invalid: true } },
        )
        expect(assessment_id).to be_nil
      end

      it 'logs analytics of the body' do
        result

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            assessment_id: nil,
            success: true,
            score:,
            errors: [],
            reasons: [],
          },
          evaluated_as_valid: false,
          score_threshold: score_threshold,
          form_class: 'RecaptchaForm',
          recaptcha_action:,
        )
      end
    end

    context 'with successful score from validation service' do
      let(:token) { 'token' }
      let(:score) { score_threshold + 0.1 }

      around do |example|
        stubbed_request = stub_recaptcha_response(body: { success: true, score: }, token:)
        example.run
        expect(stubbed_request).to have_been_made.once
      end

      it 'is successful' do
        response, assessment_id = result

        expect(response.to_h).to eq(success: true)
        expect(assessment_id).to be_nil
      end

      it 'logs analytics of the body' do
        result

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            assessment_id: nil,
            success: true,
            score:,
            errors: [],
            reasons: [],
          },
          evaluated_as_valid: true,
          score_threshold: score_threshold,
          form_class: 'RecaptchaForm',
          recaptcha_action:,
        )
      end

      context 'with extra analytics properties', allowed_extra_analytics: [:extra] do
        let(:extra_analytics_properties) { { extra: true } }

        it 'logs analytics of the body' do
          result

          expect(analytics).to have_logged_event(
            'reCAPTCHA verify result received',
            recaptcha_result: {
              assessment_id: nil,
              success: true,
              score:,
              errors: [],
              reasons: [],
            },
            evaluated_as_valid: true,
            score_threshold: score_threshold,
            form_class: 'RecaptchaForm',
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

  def stub_recaptcha_response(body:, secret: recaptcha_secret_key, token: nil)
    stub_request(:post, RecaptchaForm::VERIFICATION_ENDPOINT)
      .with { |req| req.body == URI.encode_www_form(secret:, response: token) }
      .to_return(headers: { 'Content-Type': 'application/json' }, body: body.to_json)
  end
end
