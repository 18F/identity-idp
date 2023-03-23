require 'rails_helper'

RSpec.describe Api::CsrfTokenConcern, type: :controller do
  describe '#include_csrf_token_header' do
    controller ApplicationController do
      include Api::CsrfTokenConcern

      before_action :include_csrf_token_header

      def index; end
    end

    it 'includes csrf token in the response headers' do
      get :index

      expect(response.headers['X-CSRF-Token']).to be_kind_of(String)
    end
  end
end
