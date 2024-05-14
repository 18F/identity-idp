require 'rails_helper'

RSpec.describe RecaptchaConcern, type: :controller do
  describe '#allow_csp_recaptcha_src' do
    controller ApplicationController do
      include RecaptchaConcern

      before_action :allow_csp_recaptcha_src

      def index
        render plain: ''
      end
    end

    it 'overrides csp to add directives for recaptcha' do
      get :index

      csp = response.request.content_security_policy
      expect(csp.script_src).to include(*RecaptchaConcern::RECAPTCHA_SCRIPT_SRC)
      expect(csp.frame_src).to include(*RecaptchaConcern::RECAPTCHA_FRAME_SRC)
    end
  end

  describe '#add_recaptcha_resource_hints' do
    controller ApplicationController do
      include RecaptchaConcern

      after_action :add_recaptcha_resource_hints

      def index
        if params[:add_link]
          response.headers['Link'] = '<https://example.com>;rel=preconnect'
        end

        render plain: ''
      end
    end

    subject(:response) { get :index }
    let(:processed_links) do
      response.headers['Link'].split(',').map { |link| link.split(';').map(&:chomp) }
    end

    it 'adds resource hints for recaptcha to response headers' do
      response

      expect(processed_links).to match_array(
        [
          ['<https://www.google.com>', 'rel=preconnect'],
          ['<https://www.gstatic.com>', 'rel=preconnect', 'crossorigin'],
        ],
      )
    end

    context 'with existing link header' do
      subject(:response) { get :index, params: { add_link: '' } }

      it 'appends new resource hints' do
        response

        expect(processed_links).to match_array(
          [
            ['<https://example.com>', 'rel=preconnect'],
            ['<https://www.google.com>', 'rel=preconnect'],
            ['<https://www.gstatic.com>', 'rel=preconnect', 'crossorigin'],
          ],
        )
      end
    end
  end
end
