require 'rails_helper'

describe RecaptchaValidator do
  let(:score_threshold) { 0.2 }
  let(:analytics) { FakeAnalytics.new }
  subject(:validator) { RecaptchaValidator.new(score_threshold:, analytics:) }

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
    end

    context 'with missing token' do
      let(:token) { nil }

      it { expect(valid).to eq(false) }
    end

    context 'with blank token' do
      let(:token) { '' }

      it { expect(valid).to eq(false) }
    end

    context 'with unsuccessful response from validation service' do
      let(:token) { 'token' }

      before do
        stub_recaptcha_response_body(success: false, 'error-codes': ['missing-input-secret'])
      end

      it { expect(valid).to eq(true) }

      it 'logs analytics of the body' do
        valid

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            'success' => false,
            'error-codes' => ['missing-input-secret'],
          },
          evaluated_as_valid: true,
          score_threshold: score_threshold,
          exception_class: nil,
        )
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
          recaptcha_result: nil,
          evaluated_as_valid: true,
          score_threshold: score_threshold,
          exception_class: 'Faraday::ConnectionFailed',
        )
      end
    end

    context 'with failing score from validation service' do
      let(:token) { 'token' }
      let(:score) { score_threshold - 0.1 }

      before do
        stub_recaptcha_response_body(success: true, score:)
      end

      it { expect(valid).to eq(false) }

      it 'logs analytics of the body' do
        valid

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            'success' => true,
            'score' => score,
          },
          evaluated_as_valid: false,
          score_threshold: score_threshold,
          exception_class: nil,
        )
      end
    end

    context 'with successful score from validation service' do
      let(:token) { 'token' }
      let(:score) { score_threshold + 0.1 }

      before do
        stub_recaptcha_response_body(success: true, score:)
      end

      it { expect(valid).to eq(true) }

      it 'logs analytics of the body' do
        valid

        expect(analytics).to have_logged_event(
          'reCAPTCHA verify result received',
          recaptcha_result: {
            'success' => true,
            'score' => score,
          },
          evaluated_as_valid: true,
          score_threshold: score_threshold,
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

  def stub_recaptcha_response_body(body)
    stub_request(:post, RecaptchaValidator::VERIFICATION_ENDPOINT).to_return(
      headers: { 'Content-Type': 'application/json' },
      body: body.to_json,
    )
  end
end
