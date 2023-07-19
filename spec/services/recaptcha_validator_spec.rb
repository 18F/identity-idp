require 'rails_helper'

RSpec.describe RecaptchaValidator do
  let(:score_threshold) { 0.2 }
  let(:analytics) { FakeAnalytics.new }
  let(:extra_analytics_properties) { {} }
  let(:recaptcha_secret_key_v2) { 'recaptcha_secret_key_v2' }
  let(:recaptcha_secret_key_v3) { 'recaptcha_secret_key_v3' }

  subject(:validator) do
    RecaptchaValidator.new(score_threshold:, analytics:, extra_analytics_properties:)
  end

  before do
    allow(IdentityConfig.store).to receive(:recaptcha_secret_key_v2).
      and_return(recaptcha_secret_key_v2)
    allow(IdentityConfig.store).to receive(:recaptcha_secret_key_v3).
      and_return(recaptcha_secret_key_v3)
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
          body: { success: false, 'error-codes': ['timeout-or-duplicate'] },
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
            reasons: ['timeout-or-duplicate'],
            errors: [],
          },
          evaluated_as_valid: false,
          score_threshold: score_threshold,
          recaptcha_version: 3,
          validator_class: 'RecaptchaValidator',
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

          it { expect(valid).to eq(true) }

          it 'logs analytics of the body' do
            valid

            expect(analytics).to have_logged_event(
              'reCAPTCHA verify result received',
              recaptcha_result: {
                success: false,
                score: nil,
                errors: ['missing-input-secret'],
                reasons: [],
              },
              evaluated_as_valid: true,
              score_threshold: score_threshold,
              recaptcha_version: 3,
              validator_class: 'RecaptchaValidator',
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

          it { expect(valid).to eq(true) }

          it 'logs analytics of the body' do
            valid

            expect(analytics).to have_logged_event(
              'reCAPTCHA verify result received',
              recaptcha_result: {
                success: false,
                score: nil,
                errors: ['invalid-input-secret'],
                reasons: [],
              },
              evaluated_as_valid: true,
              score_threshold: score_threshold,
              recaptcha_version: 3,
              validator_class: 'RecaptchaValidator',
            )
          end
        end
      end
    end

    context 'with connection error' do
      let(:token) { 'token' }

      before do
        stub_request(:post, RecaptchaValidator::VERIFICATION_ENDPOINT).to_timeout
      end

      it { expect(valid).to eq(true) }

      it 'logs analytics of the body' do
        valid

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          evaluated_as_valid: true,
          score_threshold: score_threshold,
          recaptcha_version: 3,
          validator_class: 'RecaptchaValidator',
          exception_class: 'Faraday::ConnectionFailed',
        )
      end
    end

    context 'with failing score from validation service' do
      let(:token) { 'token' }
      let(:score) { score_threshold - 0.1 }

      before do
        stub_recaptcha_response(body: { success: true, score: }, token:)
      end

      it { expect(valid).to eq(false) }

      it 'logs analytics of the body' do
        valid

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            success: true,
            score:,
            errors: [],
            reasons: [],
          },
          evaluated_as_valid: false,
          score_threshold: score_threshold,
          recaptcha_version: 3,
          validator_class: 'RecaptchaValidator',
        )
      end
    end

    context 'with successful score from validation service' do
      let(:token) { 'token' }
      let(:score) { score_threshold + 0.1 }

      before do
        stub_recaptcha_response(body: { success: true, score: }, token:)
      end

      it { expect(valid).to eq(true) }

      it 'logs analytics of the body' do
        valid

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            success: true,
            score:,
            errors: [],
            reasons: [],
          },
          evaluated_as_valid: true,
          score_threshold: score_threshold,
          recaptcha_version: 3,
          validator_class: 'RecaptchaValidator',
        )
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
              errors: [],
              reasons: [],
            },
            evaluated_as_valid: true,
            score_threshold: score_threshold,
            recaptcha_version: 3,
            validator_class: 'RecaptchaValidator',
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

      context 'with recaptcha v2' do
        before do
          stub_recaptcha_response(
            body: { success: true, score: },
            secret: recaptcha_secret_key_v2,
            token:,
          )
        end

        subject(:validator) do
          RecaptchaValidator.new(recaptcha_version: 2, score_threshold:, analytics:)
        end

        it { expect(valid).to eq(true) }

        it 'logs analytics of the body' do
          valid

          expect(analytics).to have_logged_event(
            'reCAPTCHA verify result received',
            recaptcha_result: {
              success: true,
              score:,
              errors: [],
              reasons: [],
            },
            evaluated_as_valid: true,
            score_threshold: score_threshold,
            recaptcha_version: 2,
            validator_class: 'RecaptchaValidator',
          )
        end
      end
    end
  end

  context 'with invalid recaptcha_version' do
    subject(:validator) do
      RecaptchaValidator.new(recaptcha_version: 4, score_threshold:, analytics:)
    end

    it 'raises an error during initialization' do
      expect { validator }.to raise_error(ArgumentError)
    end
  end

  def stub_recaptcha_response(body:, secret: recaptcha_secret_key_v3, token: nil)
    stub_request(:post, RecaptchaValidator::VERIFICATION_ENDPOINT).
      with { |req| req.body == URI.encode_www_form(secret:, response: token) }.
      to_return(headers: { 'Content-Type': 'application/json' }, body: body.to_json)
  end
end
