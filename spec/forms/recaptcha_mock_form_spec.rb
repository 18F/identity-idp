require 'rails_helper'

RSpec.describe RecaptchaMockForm do
  let(:score_threshold) { 0.2 }
  let(:analytics) { FakeAnalytics.new }
  let(:score) { nil }
  let(:recaptcha_action) { 'example_action' }
  subject(:form) do
    RecaptchaMockForm.new(score_threshold:, analytics:, recaptcha_action:, score:)
  end

  around do |example|
    freeze_time { example.run }
  end

  describe '#submit' do
    let(:token) { 'token' }
    subject(:result) { form.submit(token) }

    context 'with failing score from validation service' do
      let(:score) { score_threshold - 0.1 }

      it 'is unsuccessful with error for invalid token' do
        response, assessment_id = result

        expect(response.to_h).to eq(
          success: false,
          error_details: { recaptcha_token: { invalid: true } },
        )
        expect(assessment_id).to be_kind_of(String)
      end

      it 'logs analytics of the body' do
        result

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            assessment_id: kind_of(String),
            success: true,
            score:,
            errors: [],
            reasons: [],
          },
          evaluated_as_valid: false,
          score_threshold: score_threshold,
          form_class: 'RecaptchaMockForm',
          recaptcha_action:,
        )
      end
    end

    context 'with successful score from validation service' do
      let(:token) { 'token' }
      let(:score) { score_threshold + 0.1 }

      it 'is successful' do
        response, assessment_id = result

        expect(response.to_h).to eq(success: true)
        expect(assessment_id).to be_kind_of(String)
      end

      it 'logs analytics of the body' do
        result

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            assessment_id: kind_of(String),
            success: true,
            score:,
            errors: [],
            reasons: [],
          },
          evaluated_as_valid: true,
          score_threshold: score_threshold,
          form_class: 'RecaptchaMockForm',
          recaptcha_action:,
        )
      end

      context 'without analytics' do
        let(:analytics) { nil }

        it 'validates gracefully without analytics logging' do
          result
        end
      end
    end
  end
end
