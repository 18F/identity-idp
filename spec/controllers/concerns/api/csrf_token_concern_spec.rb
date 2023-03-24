require 'rails_helper'

RSpec.describe Api::CsrfTokenConcern, type: :controller do
  describe '#add_csrf_token_header_to_response' do
    controller ApplicationController do
      include Api::CsrfTokenConcern

      before_action :add_csrf_token_header_to_response

      def index; end
    end

    it 'includes csrf token in the response headers' do
      get :index

      expect(response.headers['X-CSRF-Token']).to be_kind_of(String)
    end
  end
end
