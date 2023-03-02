require 'rails_helper'

RSpec.describe RecaptchaConcern, type: :controller do
  controller ApplicationController do
    include RecaptchaConcern

    before_action :allow_csp_recaptcha_src

    def index
      render plain: ''
    end
  end

  describe '#allow_csp_recaptcha_src' do
    it 'overrides csp to add directives for recaptcha' do
      get :index

      csp = response.request.content_security_policy
      expect(csp.script_src).to include(*RecaptchaConcern::RECAPTCHA_SCRIPT_SRC)
      expect(csp.frame_src).to include(*RecaptchaConcern::RECAPTCHA_FRAME_SRC)
    end
  end

  describe '#recoverable_recaptcha_error?' do
    let(:form) { NewPhoneForm.new(user: build_stubbed(:user)) }
    let(:errors) { ActiveModel::Errors.new(form) }
    let(:result) { FormResponse.new(success: true, errors:) }

    subject(:recoverable_recaptcha_error) { controller.recoverable_recaptcha_error?(result) }

    it { expect(recoverable_recaptcha_error).to eq(false) }

    context 'with recaptcha token error' do
      before do
        errors.add(
          :recaptcha_token,
          t('errors.messages.invalid_recaptcha_token'),
          type: :invalid_recaptcha_token,
        )
      end

      it { expect(recoverable_recaptcha_error).to eq(true) }

      context 'with error unrelated to recaptcha token' do
        before do
          errors.add(:phone, :blank, message: t('errors.messages.blank'))
        end

        it { expect(recoverable_recaptcha_error).to eq(false) }
      end
    end
  end
end
