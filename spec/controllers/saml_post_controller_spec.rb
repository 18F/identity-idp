require 'rails_helper'

describe SamlPostController do
  describe 'POST /api/saml/auth' do
    render_views
    include ActionView::Helpers::FormTagHelper

    let(:form_action_regex) { /<form.+action=".+\/api\/saml\/authpost\d{4}.+"/ }
    let(:saml_request) { 'abc123' }
    let(:relay_state) { 'def456' }
    let(:sig_alg) { 'aes256' }
    let(:signature) { 'xyz789' }

    it 'renders the appropriate form' do
      post :auth, params: {
        'SAMLRequest' => saml_request,
        'RelayState' => relay_state,
        'SigAlg' => sig_alg,
        'Signature' => signature,
      }

      expect(response.body).to match(form_action_regex)
      expect(response.body).to match(hidden_field_tag('SAMLRequest', saml_request))
      expect(response.body).to match(hidden_field_tag('RelayState', relay_state))
      expect(response.body).to match(hidden_field_tag('SigAlg', sig_alg))
      expect(response.body).to match(hidden_field_tag('Signature', signature))
    end

    it 'does not render extra parameters' do
      post :auth, params: { 'Foo' => 'bar' }

      expect(response.body).not_to match(hidden_field_tag('Foo', 'bar'))
    end

    context 'with an invalid year in the path' do
      let(:path_year) { SamlEndpoint.suffixes.last.to_i + 2 }

      before do
        allow(controller).to receive(:request).and_wrap_original do |impl|
          req = impl.call
          req.path = "https://example.gov/api/saml/auth#{path_year}"
          req
        end
      end

      it 'renders 404 not found' do
        post :auth, params: {
          'SAMLRequest' => saml_request,
          'RelayState' => relay_state,
          'SigAlg' => sig_alg,
          'Signature' => signature,
        }

        expect(response).to be_not_found
      end
    end
  end
end
