require 'rails_helper'

describe SamlCompletionController do
  describe 'GET #index' do
    render_views
    include ActionView::Helpers::FormTagHelper

    let(:form_action_regex) { /<form.+action=".+\/api\/saml\/finalauthpost\d{4}.+"/ }
    let(:saml_request) { 'abc123' }
    let(:relay_state) { 'def456' }
    let(:sig_alg) { 'aes256' }
    let(:signature) { 'xyz789' }
    let(:path_year) { '2022' }

    context 'with a valid service provider request session' do
      let(:get_params) do
        {
          SAMLRequest: saml_request,
          RelayState: relay_state,
          SigAlg: sig_alg,
          Signature: signature,
        }
      end
      let(:sp_session_request_url) { "http://example.gov/api/saml/auth#{path_year}" }

      before do
        expect(controller).to receive(:sp_session).at_least(:once).and_return(
          request_url: UriService.add_params(sp_session_request_url, get_params),
        )
      end

      it 'renders the appropriate form' do
        get :index, params: { path_year: path_year }

        expect(response.body).to match(form_action_regex)
        expect(response.body).to match(hidden_field_tag('SAMLRequest', saml_request))
        expect(response.body).to match(hidden_field_tag('RelayState', relay_state))
        expect(response.body).to match(hidden_field_tag('SigAlg', sig_alg))
        expect(response.body).to match(hidden_field_tag('Signature', signature))
      end
    end

    context 'with a blank service provider request session' do
      before { expect(controller).to receive(:sp_session).at_least(:once).and_return({}) }

      it 'renders 404 not found' do
        get :index, params: { path_year: path_year }
        expect(response).to be_not_found
      end
    end

    context 'with a nil service provider request session' do
      before { expect(controller).to receive(:sp_from_sp_session).and_return nil }

      it 'renders 404 not found' do
        get :index, params: { path_year: path_year }
        expect(response).to be_not_found
      end
    end
  end
end
