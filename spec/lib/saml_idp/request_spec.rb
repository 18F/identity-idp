require 'spec_helper'
module SamlIdp
  describe Request do
    let(:raw_request) { "<samlp:AuthnRequest AssertionConsumerServiceURL='http://localhost:3000/saml/consume' Destination='http://localhost:1337/saml/auth' ID='_af43d1a0-e111-0130-661a-3c0754403fdb' IssueInstant='2013-08-06T22:01:35Z' Version='2.0' xmlns:samlp='urn:oasis:names:tc:SAML:2.0:protocol'><saml:Issuer xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>localhost:3000</saml:Issuer><samlp:NameIDPolicy AllowCreate='true' Format='urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress' xmlns:samlp='urn:oasis:names:tc:SAML:2.0:protocol'/></samlp:AuthnRequest>" }
    subject { described_class.new raw_request }

    its(:request_id) { should == "_af43d1a0-e111-0130-661a-3c0754403fdb" }
    its(:acs_url) { should == "http://localhost:3000/saml/consume" }
    its(:service_provider) { should be_a ServiceProvider }
    its(:service_provider?) { should be_true }
    its(:issuer) { should == "localhost:3000" }
    its(:valid_signature?) { should be_true }
  end
end
