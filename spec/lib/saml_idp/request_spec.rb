require 'spec_helper'
module SamlIdp
  describe Request do
    let(:raw_authn_request) { "<samlp:AuthnRequest AssertionConsumerServiceURL='http://localhost:3000/saml/consume' Destination='http://localhost:1337/saml/auth' ID='_af43d1a0-e111-0130-661a-3c0754403fdb' IssueInstant='2013-08-06T22:01:35Z' Version='2.0' xmlns:samlp='urn:oasis:names:tc:SAML:2.0:protocol'><saml:Issuer xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>localhost:3000</saml:Issuer><samlp:NameIDPolicy AllowCreate='true' Format='urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress' xmlns:samlp='urn:oasis:names:tc:SAML:2.0:protocol'/><samlp:RequestedAuthnContext Comparison='exact'><saml:AuthnContextClassRef xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>urn:oasis:names:tc:SAML:2.0:ac:classes:Password</saml:AuthnContextClassRef></samlp:RequestedAuthnContext></samlp:AuthnRequest>" }

    describe "deflated request" do
      let(:deflated_request) { Base64.encode64(Zlib::Deflate.deflate(raw_authn_request, 9)[2..-5]) }

      subject { described_class.from_deflated_request deflated_request }

      it "inflates" do
        subject.request_id.should == "_af43d1a0-e111-0130-661a-3c0754403fdb"
      end

      it "handles invalid SAML" do
        req = described_class.from_deflated_request "bang!"
        req.valid?.should == false
      end
    end

    describe "authn request" do
      subject { described_class.new raw_authn_request }

      it "has a valid request_id" do
        subject.request_id.should == "_af43d1a0-e111-0130-661a-3c0754403fdb"
      end

      it "has a valid acs_url" do
        subject.acs_url.should == "http://localhost:3000/saml/consume"
      end

      it "has a valid service_provider" do
        subject.service_provider.should be_a ServiceProvider
      end

      it "has a valid service_provider" do
        subject.service_provider.should be_truthy
      end

      it "has a valid issuer" do
        subject.issuer.should == "localhost:3000"
      end

      it "has a valid valid_signature" do
        subject.valid_signature?.should be_truthy
      end

      it "should return acs_url for response_url" do
        subject.response_url.should == subject.acs_url
      end

      it "is a authn request" do
        subject.authn_request?.should == true
      end

      it "fetches internal request" do
        subject.request['ID'].should == subject.request_id
      end

      it "has a valid authn context" do
        subject.requested_authn_context.should == "urn:oasis:names:tc:SAML:2.0:ac:classes:Password"
      end

      it "does not permit empty issuer" do
        raw_req = raw_authn_request.gsub('localhost:3000', '')
        authn_request = described_class.new raw_req
        authn_request.issuer.should_not == ''
        authn_request.issuer.should == nil
      end
    end

    describe "logout request" do
      let(:raw_logout_request) { "<LogoutRequest ID='_some_response_id' Version='2.0' IssueInstant='2010-06-01T13:00:00Z' Destination='http://localhost:3000/saml/logout' xmlns='urn:oasis:names:tc:SAML:2.0:protocol'><Issuer xmlns='urn:oasis:names:tc:SAML:2.0:assertion'>http://example.com</Issuer><NameID xmlns='urn:oasis:names:tc:SAML:2.0:assertion' Format='urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'>some_name_id</NameID><SessionIndex>abc123index</SessionIndex></LogoutRequest>" }

      subject { described_class.new raw_logout_request }

      it "has a valid request_id" do
        subject.request_id.should == '_some_response_id'
      end

      it "should be flagged as a logout_request" do
        subject.logout_request?.should == true
      end

      it "should have a valid name_id" do
        subject.name_id.should == 'some_name_id'
      end

      it "should have a session index" do
        subject.session_index.should == 'abc123index'
      end

      it "should have a valid issuer" do
        subject.issuer.should == 'http://example.com'
      end

      it "fetches internal request" do
        subject.request['ID'].should == subject.request_id
      end

      it "should return logout_url for response_url" do
        subject.response_url.should == subject.logout_url
      end
    end
  end
end
