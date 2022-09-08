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

    context 'with SAML protocol params passed in appropriately via an internal redirect' do
      let(:get_params) { "?SAMLRequest=#{saml_request}&RelayState=#{relay_state}&SigAlg=#{sig_alg}&Signature=#{signature}" }
      let(:sp_session_request_url) { 'http://example.gov/api/saml/auth2022' }

      before do
        expect(controller).to receive(:sp_session).at_least(:once).and_return(
          request_url: sp_session_request_url + get_params
        )
      end

      it 'renders the appropriate form' do
        get :index

        expect(response.body).to match(form_action_regex)
        expect(response.body).to match(hidden_field_tag('SAMLRequest', saml_request))
        expect(response.body).to match(hidden_field_tag('RelayState', relay_state))
        expect(response.body).to match(hidden_field_tag('SigAlg', sig_alg))
        expect(response.body).to match(hidden_field_tag('Signature', signature))
      end
    end
  end
end
