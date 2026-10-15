require 'rails_helper'

RSpec.describe Users::StsConsentController do
  let(:user) { create(:user, :fully_registered) }
  let(:sp) { create(:service_provider) }
  let(:issuer) { sp.issuer }
  let(:sp_request_url) { 'http://example.com/request/url' }
  let(:sp_request_id) { '123abc' }
  let(:sp_session) { { issuer: issuer, request_url: sp_request_url, request_id: sp_request_id } }
  let(:token_exchange_enabled) { true }

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled)
      .and_return(token_exchange_enabled)
    stub_analytics
    stub_sign_in(user)
    controller.session[:sp] = sp_session
  end

  describe '#new' do
    it 'renders for a signed in user with an SP in session' do
      get :new

      expect(response).to render_template(:new)
      expect(@analytics).to have_logged_event(:sts_consent_visited)
    end

    it 'redirects for a user without an SP request url' do
      controller.session[:sp] = {}

      get :new

      expect(response).to redirect_to(account_url)
    end

    context 'when token exchange is disabled' do
      let(:token_exchange_enabled) { false }

      it 'redirects to the account page' do
        get :new

        expect(response).to redirect_to(account_url)
      end
    end
  end

  describe '#create' do
    context 'when consent is given' do
      it 'persists consent and redirects to the sp request url' do
        expect do
          post :create, params: { sts_consent_form: { consent_given: '1' } }
        end.to change { UserConsentSts.count }.by(1)

        consent = UserConsentSts.last
        expect(consent.user).to eq(user)
        expect(consent.target_app).to eq(issuer)

        expect(response).to redirect_to(sp_request_url)
        expect(@analytics).to have_logged_event(
          :sts_consent_submitted,
          success: true,
        )
      end
    end

    context 'when consent is not given' do
      it 'does not persist consent and re-renders the form' do
        expect do
          post :create, params: { sts_consent_form: { consent_given: '0' } }
        end.not_to change { UserConsentSts.count }

        expect(response).to render_template(:new)
        expect(@analytics).to have_logged_event(
          :sts_consent_submitted,
          success: false,
          error_details: { consent_given: { required_checkbox: true } },
        )
      end
    end

    context 'when token exchange is disabled' do
      let(:token_exchange_enabled) { false }

      it 'redirects to the account page' do
        post :create, params: { sts_consent_form: { consent_given: '1' } }

        expect(response).to redirect_to(account_url)
      end
    end
  end
end
