require 'rails_helper'

describe Test::PivCacAuthenticationTestSubjectController do
  describe 'when not in development' do
    before(:each) do
      allow(Rails.env).to receive(:development?) { false }
      allow(Figaro.env).to receive(:enable_test_routes) { 'true' }
      allow(Figaro.env).to receive(:piv_cac_enabled) { 'true' }
    end

    describe 'FeatureManagement#development_and_piv_cac_entry_enabled?' do
      it 'is disabled' do
        expect(FeatureManagement.development_and_piv_cac_entry_enabled?).to be_falsey
      end
    end

    describe 'routes' do
      it 'has a route to GET new' do
        expect(test_piv_cac_entry_url).to_not be_nil
      end
    end

    describe 'GET new' do
      it 'redirects to root_url' do
        get :new
        expect(response).to redirect_to(root_url)
      end
    end

    describe 'POST create' do
      it 'redirects to root_url' do
        post :create
        expect(response).to redirect_to(root_url)
      end
    end
  end

  describe 'when in development' do
    before(:each) do
      allow(Rails.env).to receive(:development?) { true }
      allow(Figaro.env).to receive(:enable_test_routes) { 'true' }
      allow(Figaro.env).to receive(:piv_cac_enabled) { 'true' }
    end

    describe 'FeatureManagement#development_and_piv_cac_entry_enabled?' do
      it 'is enabled' do
        expect(FeatureManagement.development_and_piv_cac_entry_enabled?).to be_truthy
      end
    end

    describe 'GET new' do
      before(:each) do
        @request.headers['Referer'] = setup_piv_cac_url
      end

      it 'renders a page' do
        get :new
        expect(response).to render_template(:new)
      end
    end

    describe 'POST create' do
      let(:expected_redirect) do
        uri = URI(setup_piv_cac_url)
        uri.query = ''
        uri.fragment = ''
        uri.query = "token=TEST:#{CGI.escape(serialized_token)}"
        uri.to_s
      end

      let(:expected_token) { {'error' => 'certificate.none', 'nonce' => nonce }}
      let(:serialized_token) { expected_token.to_json }
      let(:nonce) { 'nonce' }

      it 'returns a redirect' do
        allow(subject).to receive(:user_session).and_return(piv_cac_nonce: nonce)

        post :create, params: { referer: setup_piv_cac_url }

        expect(response).to redirect_to(expected_redirect)
      end
    end
  end
end
