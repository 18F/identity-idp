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
end
