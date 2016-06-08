require 'spec_helper'
require 'saml_idp/logout_request_builder'

module SamlIdp
  describe LogoutRequestBuilder do
    before do
      Timecop.freeze(Time.local(1990))
    end

    after do
      Timecop.return
    end

    let(:response_id) { 'some_response_id' }
    let(:issuer_uri) { 'http://example.com' }
    let(:saml_slo_url) { 'http://localhost:3000/saml/logout' }
    let(:name_id) { 'some_name_id' }
    let(:algorithm) { OpenSSL::Digest::SHA256 }

    subject do
      described_class.new(
        response_id,
        issuer_uri,
        saml_slo_url,
        name_id,
        algorithm
      )
    end

    it "is a valid SloLogoutrequest" do
      Timecop.travel(Time.zone.local(2010, 6, 1, 13, 0, 0)) do
        slo_request = OneLogin::RubySaml::SloLogoutrequest.new(
          subject.encoded,
          settings: saml_settings('localhost:3000')
        )
        slo_request.soft = false
        expect(slo_request.is_valid?).to eq true
      end
    end
  end
end
