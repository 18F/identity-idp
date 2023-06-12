require 'rails_helper'

RSpec.describe RecaptchaMockValidator do
  let(:score_threshold) { 0.2 }
  let(:analytics) { FakeAnalytics.new }
  let(:score) { nil }
  subject(:validator) { RecaptchaMockValidator.new(score_threshold:, analytics:, score:) }

  around do |example|
    freeze_time { example.run }
  end

  describe '#valid?' do
    let(:token) { 'token' }
    subject(:valid) { validator.valid?(token) }

    context 'with failing score from validation service' do
      let(:score) { score_threshold - 0.1 }

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
          validator_class: 'RecaptchaMockValidator',
          exception_class: nil,
        )
      end
    end

    context 'with successful score from validation service' do
      let(:token) { 'token' }
      let(:score) { score_threshold + 0.1 }

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
          validator_class: 'RecaptchaMockValidator',
          exception_class: nil,
        )
      end

      context 'without analytics' do
        let(:analytics) { nil }

        it 'validates gracefully without analytics logging' do
          valid
        end
      end
    end
  end
end
