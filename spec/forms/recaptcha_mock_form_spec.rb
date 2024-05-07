require 'rails_helper'

RSpec.describe RecaptchaMockForm do
  let(:score_threshold) { 0.2 }
  let(:analytics) { FakeAnalytics.new }
  let(:score) { nil }
  subject(:form) do
    RecaptchaMockForm.new(score_threshold:, analytics:, score:)
  end

  around do |example|
    freeze_time { example.run }
  end

  describe '#submit' do
    let(:token) { 'token' }
    subject(:response) { form.submit(token) }

    context 'with failing score from validation service' do
      let(:score) { score_threshold - 0.1 }

      it 'is unsuccessful with error for invalid token' do
        expect(response.to_h).to eq(
          success: false,
          error_details: { recaptcha_token: { invalid: true } },
        )
      end

      it 'logs analytics of the body' do
        response

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
          form_class: 'RecaptchaMockForm',
        )
      end
    end

    context 'with successful score from validation service' do
      let(:token) { 'token' }
      let(:score) { score_threshold + 0.1 }

      it 'is successful' do
        expect(response.to_h).to eq(success: true)
      end

      it 'logs analytics of the body' do
        response

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
          form_class: 'RecaptchaMockForm',
        )
      end

      context 'without analytics' do
        let(:analytics) { nil }

        it 'validates gracefully without analytics logging' do
          response
        end
      end
    end
  end
end
