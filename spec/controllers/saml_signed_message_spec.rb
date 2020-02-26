require 'rails_helper'

describe SamlIdpController do
  include SamlAuthHelper

  before do
    # All the tests here were written prior to the interstitial
    # authorization confirmation page so let's force the system
    # to skip past that page
    allow(controller).to receive(:auth_count).and_return(2)
  end

  render_views

  describe 'GET /api/saml/auth' do
    # let(:xmldoc) { SamlResponseDoc.new('controller', 'response_assertion', response) }

    context "SP's can have signed_response_message_requested set" do
      context 'with signed_response_message_requested true' do
        it 'finds a Signature in the message' do
          user = create(:user, :signed_up)
          generate_saml_response(user, sp_requesting_signed_saml_response_settings)
          saml_response_encoded = response.body.match(/.*id=\"SAMLResponse\" value=\"(.*)\" \/><input type=\"submit\"/)[1]
          saml_response_text = Base64.decode64(saml_response_encoded)
          saml_response = ::REXML::Document.new(saml_response_text)
          signature_count = REXML::XPath.match(saml_response, '//ds:Signature').length

          expect(signature_count).to eq 2
        end
      end

      context 'with signed_response_message_requested false' do
        it 'does not find Signature in the message' do
          user = create(:user, :signed_up)
          generate_saml_response(user, sp_not_requesting_signed_saml_response_settings)
          saml_response_encoded = response.body.match(/.*id=\"SAMLResponse\" value=\"(.*)\" \/><input type=\"submit\"/)[1]
          saml_response_text = Base64.decode64(saml_response_encoded)
          saml_response = ::REXML::Document.new(saml_response_text)
          signature_count = REXML::XPath.match(saml_response, '//ds:Signature').length

          expect(signature_count).to eq 1
        end
      end
    end
  end
end
