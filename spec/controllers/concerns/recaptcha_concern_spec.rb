require 'rails_helper'

RSpec.describe RecaptchaConcern, type: :controller do
  controller ApplicationController do
    include RecaptchaConcern

    def index
      render plain: ''
    end
  end

  before do
    routes.draw do
      get 'index' => 'anonymous#index'
    end
  end

  it 'does not modify csp' do
    expect(controller).not_to receive(:allow_csp_recaptcha_src)

    get :index
  end

  context 'with including controller enabling recaptcha' do
    controller ApplicationController do
      include RecaptchaConcern

      def index
        render plain: ''
      end

      private

      def recaptcha_enabled?
        true
      end
    end

    it 'overrides csp to add directives for recaptcha' do
      expect(controller).to receive(:allow_csp_recaptcha_src).and_call_original

      get :index

      csp = response.request.content_security_policy
      expect(csp.script_src).to include(*RecaptchaConcern::RECAPTCHA_SCRIPT_SRC)
      expect(csp.frame_src).to include(*RecaptchaConcern::RECAPTCHA_FRAME_SRC)
    end
  end
end
