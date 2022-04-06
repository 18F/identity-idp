require 'rails_helper'

describe Redirect::ReturnToSpController do
  let(:current_sp) { build(:service_provider) }

  before do
    allow(subject).to receive(:current_sp).and_return(current_sp)
    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  describe '#cancel' do
    context 'when there is no SP' do
      let(:current_sp) { nil }

      it 'redirects to the account' do
        get 'cancel'

        expect(response).to redirect_to account_url
      end
    end

    context 'when there is an SP request in the session' do
      it 'redirects to the redirect URI in the request url' do
        redirect_uri = 'https://sp.gov/result'
        state = '123abc'
        sp_request_url = UriService.add_params(
          'https://example.gov/authorize', state: state, redirect_uri: redirect_uri
        )
        session[:sp] = { request_url: sp_request_url }

        get 'cancel'

        expected_redirect_uri = SpReturnUrlResolver.new(
          service_provider: current_sp, oidc_state: state, oidc_redirect_uri: redirect_uri,
        ).return_to_sp_url
        expect(response).to redirect_to(expected_redirect_uri)
        expect(@analytics).to have_received(:track_event).with(
          Analytics::RETURN_TO_SP_CANCEL,
          redirect_url: expected_redirect_uri,
        )
      end
    end

    context 'when there is a SP request url for the request id param' do
      it 'redirects to the redirect URI in the request url' do
        redirect_uri = 'https://sp.gov/result'
        state = '123abc'
        sp_request_url = UriService.add_params(
          'https://example.gov/authorize', state: state, redirect_uri: redirect_uri
        )
        sp_request = ServiceProviderRequest.new(url: sp_request_url)
        allow(subject).to receive(:service_provider_request).and_return(sp_request)

        get 'cancel'

        expected_redirect_uri = SpReturnUrlResolver.new(
          service_provider: current_sp, oidc_state: state, oidc_redirect_uri: redirect_uri,
        ).return_to_sp_url
        expect(response).to redirect_to(expected_redirect_uri)
        expect(@analytics).to have_received(:track_event).with(
          Analytics::RETURN_TO_SP_CANCEL,
          redirect_url: expected_redirect_uri,
        )
      end
    end

    context 'when there is an SP in the session without a request url' do
      it 'redirects to the configured request url' do
        current_sp.return_to_sp_url = 'https://sp.gov/return_to_sp'

        get 'cancel'

        expect(response).to redirect_to('https://sp.gov/return_to_sp')
        expect(@analytics).to have_received(:track_event).with(
          Analytics::RETURN_TO_SP_CANCEL,
          redirect_url: 'https://sp.gov/return_to_sp',
        )
      end
    end
  end

  describe '#failure_to_proof' do
    context 'when there is no SP' do
      let(:current_sp) { nil }

      it 'redirects to the account' do
        get 'failure_to_proof'

        expect(response).to redirect_to account_url
      end
    end

    context 'when there is an SP in the session' do
      it 'redirects to the SP' do
        current_sp.failure_to_proof_url = 'https://sp.gov/failure_to_proof'

        get 'failure_to_proof'

        expect(response).to redirect_to('https://sp.gov/failure_to_proof')
        expect(@analytics).to have_received(:track_event).with(
          'Return to SP: Failed to proof',
          hash_including(redirect_url: 'https://sp.gov/failure_to_proof'),
        )
      end
    end

    context 'with step or location parameters' do
      it 'logs with extra analytics properties' do
        get 'failure_to_proof', params: { step: 'first', location: 'bottom' }

        expect(@analytics).to have_received(:track_event).with(
          'Return to SP: Failed to proof',
          hash_including(
            redirect_url: a_kind_of(String),
            step: 'first',
            location: 'bottom',
          ),
        )
      end
    end
  end
end
