# encoding: utf-8
require 'spec_helper'

describe SamlIdp::Controller do
  include SamlIdp::Controller

  def render(*)
  end

  def params
    @params ||= {}
  end

  it "should find the SAML ACS URL" do
    requested_saml_acs_url = "https://example.com/saml/consume"
    params[:SAMLRequest] = make_saml_request(requested_saml_acs_url)
    validate_saml_request
    expect(saml_acs_url).to eq(requested_saml_acs_url)
  end

  context "SP-initiated logout w/o embed" do
    before do
      SamlIdp.configure do |config|
        config.service_provider.finder = lambda do |_|
          {
            cert: SamlIdp::Default::X509_CERTIFICATE,
            private_key: SamlIdp::Default::SECRET_KEY,
            fingerprint: SamlIdp::Default::FINGERPRINT,
            assertion_consumer_logout_service_url: 'http://foo.example.com/sp-initiated/slo'
          }
        end
      end
    end

    it "should respect Logout Request" do
      request_url = URI.parse(make_sp_logout_request)
      params.merge!(Rack::Utils.parse_nested_query(request_url.query)).symbolize_keys!
      decode_request(params[:SAMLRequest])
      expect(saml_request.logout_request?).to eq true
      expect(valid_saml_request?).to eq true
    end

    it "requires Signature be present in params" do
      request_url = URI.parse(make_sp_logout_request)
      params.merge!(Rack::Utils.parse_nested_query(request_url.query)).symbolize_keys!
      params.delete(:Signature)
      decode_request(params[:SAMLRequest])

      expect(saml_request.logout_request?).to eq true
      expect(valid_saml_request?).to eq false
    end
  end

  context "SAML Responses" do
    before(:each) do
      params[:SAMLRequest] = make_saml_request
      validate_saml_request
    end

    let(:principal) { double email_address: "foo@example.com" }
    let (:encryption_opts) do
      {
        cert: SamlIdp::Default::X509_CERTIFICATE,
        block_encryption: 'aes256-cbc',
        key_transport: 'rsa-oaep-mgf1p',
      }
    end

    it "should create a SAML Response" do
      saml_response = encode_response(principal)
      response = OneLogin::RubySaml::Response.new(saml_response)
      expect(response.name_id).to eq("foo@example.com")
      expect(response.issuers.first).to eq("http://example.com")
      response.settings = saml_settings
      expect(response.is_valid?).to be_truthy
    end

    it "should create a SAML Logout Response" do
      params[:SAMLRequest] = make_saml_logout_request
      validate_saml_request
      expect(saml_request.logout_request?).to eq true
      saml_response = encode_response(principal)
      response = OneLogin::RubySaml::Logoutresponse.new(saml_response, saml_settings)
      expect(response.validate).to eq(true)
      expect(response.issuer).to eq("http://example.com")
    end

    [:sha1, :sha256, :sha384, :sha512].each do |algorithm_name|
      it "should create a SAML Response using the #{algorithm_name} algorithm" do
        self.algorithm = algorithm_name
        saml_response = encode_response(principal)
        response = OneLogin::RubySaml::Response.new(saml_response)
        expect(response.name_id).to eq("foo@example.com")
        expect(response.issuers.first).to eq("http://example.com")
        response.settings = saml_settings
        expect(response.is_valid?).to be_truthy
      end

      it "should encrypt SAML Response assertion" do
        self.algorithm = algorithm_name
        saml_response = encode_response(principal, encryption: encryption_opts)
        resp_settings = saml_settings
        resp_settings.private_key = SamlIdp::Default::SECRET_KEY
        response = OneLogin::RubySaml::Response.new(saml_response, settings: resp_settings)
        expect(response.document.to_s).not_to match("foo@example.com")
        expect(response.decrypted_document.to_s).to match("foo@example.com")
        expect(response.name_id).to eq("foo@example.com")
        expect(response.issuers.first).to eq("http://example.com")
        expect(response.is_valid?).to be_truthy
      end
    end
  end

end
