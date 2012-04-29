# encoding: utf-8
require 'spec_helper'

describe SamlIdp::Controller do
  include SamlIdp::Controller

  def params
    @params ||= {}
  end

  it "should find the SAML ACS URL" do
    requested_saml_acs_url = "https://example.com/saml/consume"
    params[:SAMLRequest] = make_saml_request(requested_saml_acs_url)
    validate_saml_request
    saml_acs_url.should == requested_saml_acs_url
  end

  context "SAML Responses" do
    before(:each) do
      params[:SAMLRequest] = make_saml_request
      validate_saml_request
    end

    it "should create a SAML Response" do
      saml_response = encode_SAMLResponse("foo@example.com")
      response = Onelogin::Saml::Response.new(saml_response)
      response.name_id.should == "foo@example.com"
      response.issuer.should == "http://example.com"
      response.settings = saml_settings
      response.is_valid?.should be_true
    end

    [:sha1, :sha256].each do |algorithm_name|
      it "should create a SAML Response using the #{algorithm_name} algorithm" do
        self.algorithm = algorithm_name
        saml_response = encode_SAMLResponse("foo@example.com")
        response = Onelogin::Saml::Response.new(saml_response)
        response.name_id.should == "foo@example.com"
        response.issuer.should == "http://example.com"
        response.settings = saml_settings
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
          response.settings = saml_settings
          response.is_valid?.should be_true
        end
      end
    end
  end

end