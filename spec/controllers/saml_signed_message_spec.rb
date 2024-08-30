require 'rails_helper'

RSpec.describe SamlIdpController do
  include SamlAuthHelper

  before do
    # All the tests here were written prior to the interstitial
    # authorization confirmation page so let's force the system
    # to skip past that page
    allow(controller).to receive(:auth_count).and_return(2)
  end

  render_views

  describe 'GET /api/saml/auth' do
    context "SP's can have signed_response_message_requested set" do
      let(:user) { create(:user, :fully_registered) }
      let(:saml_response_encoded) do
        Nokogiri::HTML(response.body).css('#SAMLResponse').first.attributes['value'].to_s
      end
      let(:saml_response_text) { Base64.decode64(saml_response_encoded) }
      let(:saml_response) { REXML::Document.new(saml_response_text) }

      context 'with signed_response_message_requested true' do
        before do
          settings = saml_settings(
            overrides: { issuer: 'test_saml_sp_requesting_signed_response_message' },
          )
          generate_saml_response(user, settings)
        end

        it 'finds Signatures in the message and assertion' do
          signature_count = REXML::XPath.match(saml_response, '//ds:Signature').length

          expect(signature_count).to eq 2
        end

        # rubocop:disable Layout/LineLength
        it 'finds a Signature referencing the Response' do
          response_id = REXML::XPath.match(saml_response, '//samlp:Response').first.attributes['ID']
          signature_ref = REXML::XPath.match(saml_response, '//ds:Reference').first.attributes['URI'][1..-1]

          expect(signature_ref).to eq response_id
        end
      end

      context 'with signed_response_message_requested false' do
        before do
          generate_saml_response(
            user,
            saml_settings(
              overrides: { issuer: 'test_saml_sp_not_requesting_signed_response_message' },
            ),
          )
        end

        it 'only finds one Signature' do
          signature_count = REXML::XPath.match(saml_response, '//ds:Signature').length

          expect(signature_count).to eq 1
        end

        it 'only finds a Signature referencing the Assertion' do
          assertion_id = REXML::XPath.match(saml_response, '//Assertion').first.attributes['ID']
          signature_ref = REXML::XPath.match(saml_response, '//ds:Reference').first.attributes['URI'][1..-1]

          expect(signature_ref).to eq assertion_id
        end
        # rubocop:enable Layout/LineLength
      end
    end
  end
end
