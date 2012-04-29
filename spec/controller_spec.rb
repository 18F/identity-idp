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

  context "SAML Responses" do
    before(:each) do
      requested_saml_acs_url = "https://foo.example.com/saml/consume"
      @saml_config = saml_settings(requested_saml_acs_url)
      auth_request = Onelogin::Saml::Authrequest.new
      auth_url = auth_request.create(@saml_config)
      params[:SAMLRequest] = CGI.unescape(auth_url.split("=").last)
      validate_saml_request
    end

    it "should create a SAML Response" do
      saml_response = encode_SAMLResponse("foo@example.com")
      response = Onelogin::Saml::Response.new(saml_response)
      response.name_id.should == "foo@example.com"
      response.issuer.should == "http://example.com"
      response.settings = @saml_config
      response.is_valid?.should be_true
    end

    [:sha1, :sha256].each do |algorithm_name|
      it "should create a SAML Response using the #{algorithm_name} algorithm" do
        self.algorithm = algorithm_name
        saml_response = encode_SAMLResponse("foo@example.com")
        response = Onelogin::Saml::Response.new(saml_response)
        response.name_id.should == "foo@example.com"
        response.issuer.should == "http://example.com"
        response.settings = @saml_config
        response.is_valid?.should be_true
      end
    end

    [:sha384, :sha512].each do |algorithm_name|
      it "should create a SAML Response using the #{algorithm_name} algorithm" do
        pending "release of ruby-saml v0.5.4" do
          self.algorithm = algorithm_name
          saml_response = encode_SAMLResponse("foo@example.com")
          response = Onelogin::Saml::Response.new(saml_response)
          response.name_id.should == "foo@example.com"
          response.issuer.should == "http://example.com"
          response.settings = @saml_config
          response.is_valid?.should be_true
        end
      end
    end
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