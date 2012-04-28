# encoding: utf-8
require 'spec_helper'

describe SamlIdp::Controller do
  include SamlIdp::Controller

  def params
    @params ||= {}
  end

  it "should find the SAML ACS URL" do
    requested_saml_acs_url = "https://foo.example.com/saml/consume"
    auth_request = Onelogin::Saml::Authrequest.new
    auth_url = auth_request.create(saml_settings(requested_saml_acs_url))
    params[:SAMLRequest] = CGI.unescape(auth_url.split("=").last)

    validate_saml_request
    saml_acs_url.should == requested_saml_acs_url
  end

  it "should create a SAML Response" do
    requested_saml_acs_url = "https://foo.example.com/saml/consume"
    saml_config = saml_settings(requested_saml_acs_url)
    auth_request = Onelogin::Saml::Authrequest.new
    auth_url = auth_request.create(saml_config)
    params[:SAMLRequest] = CGI.unescape(auth_url.split("=").last)
    validate_saml_request
    saml_response = encode_SAMLResponse("foo@example.com")

    response = Onelogin::Saml::Response.new(saml_response)
    response.name_id.should == "foo@example.com"
    response.issuer.should == "http://example.com"
    response.settings = saml_config
    response.is_valid?.should be_true
  end

  private

    def saml_settings(saml_acs_url)
      settings = Onelogin::Saml::Settings.new
      settings.assertion_consumer_service_url = saml_acs_url
      settings.issuer = "http://example.com/issuer"
      settings.idp_sso_target_url = "http://idp.com/saml/idp"
      settings.idp_cert_fingerprint = SamlIdp::Default::FINGERPRINT
      settings.name_identifier_format = SamlIdp::Default::NAME_ID_FORMAT
      settings
    end

end