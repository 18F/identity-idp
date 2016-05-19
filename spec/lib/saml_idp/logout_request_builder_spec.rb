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
    let(:session_index) { 'abc123index' }
    let(:assertion_opts) do
      {
        reference_id: SamlIdp.config.reference_id_generator.call,
        audience_uri: 'example.com/audience',
        algorithm: OpenSSL::Digest::SHA256
      }
    end 

    subject do
      described_class.new(
        response_id,
        issuer_uri,
        saml_slo_url,
        name_id,
        session_index,
        assertion_opts
      )
    end

    it "is a valid SloLogoutrequest" do
      Timecop.travel(Time.zone.local(2010, 6, 1, 13, 0, 0)) do
        slo_request = OneLogin::RubySaml::SloLogoutrequest.new(
          Base64.strict_encode64(subject.signed),
          settings: saml_settings('localhost:3000')
        )
        #slo_request.soft = false  # TODO only available in ruby-saml >= 1.2
        expect(slo_request.is_valid?).to eq true
      end
    end
  end
end
