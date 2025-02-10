require 'rails_helper'

RSpec.describe Idv::AccountVerifiedCtaVisitedController, type: :controller do
  let(:params) { {} }

  let(:service_provider) { nil }

  before do
    stub_analytics

    allow(controller).to receive(:service_provider)
      .and_return(service_provider)
  end

  describe 'GET #show' do
    subject(:action) { get :show, params: }

    context 'issuer provided and post_idv_follow_up_url present' do
      let(:service_provider) do
        build(
          :service_provider,
          issuer: 'urn:my:awesome:issuer',
          post_idv_follow_up_url: 'https://some-sp.com',
        )
      end

      let(:params) do
        { issuer: 'urn:my:awesome:issuer', campaign_id: '123234234' }
      end

      it 'redirects to the service provider follow_up url and logs event' do
        action

        aggregate_failures 'verify response' do
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to('https://some-sp.com')
        end

        expect(@analytics).to have_logged_event(
          :idv_account_verified_cta_visited,
          issuer: 'urn:my:awesome:issuer',
          campaign_id: '123234234',
        )
      end
    end

    context 'issuer provided and service provider has no return URL or other configured URI' do
      let(:service_provider) do
        build(
          :service_provider,
          issuer: 'urn:my:awesome:issuer',
          return_to_sp_url: nil,
          post_idv_follow_up_url: nil,
          acs_url: nil,
          redirect_uris: nil,
        )
      end

      let(:params) do
        { issuer: 'urn:my:awesome:issuer', campaign_id: '123234234' }
      end

      it 'does not redirect to the service provider and does not log an event' do
        action

        expect(response).to have_http_status(:bad_request)
        expect(@analytics).not_to have_logged_event(
          :idv_account_verified_cta_visited,
        )
      end
    end

    context 'unknown service provider' do
      let(:service_provider) { nil }

      let(:params) do
        { issuer: 'urn:unknown:issuer', campaign_id: '123234234' }
      end

      it 'does not redirect to the service provider and does not log an event' do
        action

        expect(response).to have_http_status(:bad_request)
        expect(@analytics).not_to have_logged_event(
          :idv_account_verified_cta_visited,
        )
      end
    end

    context 'issuer is missing' do
      let(:service_provider) { nil }

      let(:params) do
        { campaign_id: '123234234' }
      end

      it 'redirects to secure.login.gov' do
        action

        aggregate_failures 'verify response' do
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(root_url)
        end
        expect(@analytics).to have_logged_event(
          :idv_account_verified_cta_visited,
          campaign_id: '123234234',
        )
      end
    end
  end
end
