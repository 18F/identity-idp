require 'spec_helper'
module SamlIdp
  describe ResponseBuilder do
    let(:response_id) { "abc" }
    let(:issuer_uri) { "http://example.com" }
    let(:saml_acs_url) { "http://sportngin.com" }
    let(:saml_request_id) { "134" }
    let(:assertion_and_signature) { "<Assertion xmlns=\"urn:oasis:names:tc:SAML:2.0:assertion\" ID=\"_abc\" IssueInstant=\"2013-07-31T05:00:00Z\" Version=\"2.0\"><Issuer>http://sportngin.com</Issuer><signature>stuff</signature><Subject><NameID Format=\"urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress\">jon.phenow@sportngin.com</NameID><SubjectConfirmation Method=\"urn:oasis:names:tc:SAML:2.0:cm:bearer\"><SubjectConfirmationData InResponseTo=\"123\" NotOnOrAfter=\"2013-07-31T05:03:00Z\" Recipient=\"http://saml.acs.url\"/></SubjectConfirmation></Subject><Conditions NotBefore=\"2013-07-31T04:59:55Z\" NotOnOrAfter=\"2013-07-31T06:00:00Z\"><AudienceRestriction><Audience>http://example.com</Audience></AudienceRestriction></Conditions><AttributeStatement><Attribute Name=\"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress\"><AttributeValue>jon.phenow@sportngin.com</AttributeValue></Attribute></AttributeStatement><AuthnStatment AuthnInstant=\"2013-07-31T05:00:00Z\" SessionIndex=\"_abc\"><AuthnContext><AuthnContextClassRef>urn:federation:authentication:windows</AuthnContextClassRef></AuthnContext></AuthnStatment></Assertion>" }
    subject { described_class.new(
      response_id,
      issuer_uri,
      saml_acs_url,
      saml_request_id,
      assertion_and_signature
    ) }

    before do
      Time.stub now: Time.parse("Jul 31 2013")
    end

    it "builds a legit raw XML file" do
      subject.raw.should == "<samlp:Response ID=\"_abc\" Version=\"2.0\" IssueInstant=\"2013-07-31T05:00:00Z\" Destination=\"http://sportngin.com\" Consent=\"urn:oasis:names:tc:SAML:2.0:consent:unspecified\" InResponseTo=\"134\" xmlns:samlp=\"urn:oasis:names:tc:SAML:2.0:protocol\"><Issuer xmlns=\"urn:oasis:names:tc:SAML:2.0:assertion\">http://example.com</Issuer><samlp:Status><samlp:StatusCode Value=\"urn:oasis:names:tc:SAML:2.0:status:Success\"/></samlp:Status><Assertion xmlns=\"urn:oasis:names:tc:SAML:2.0:assertion\" ID=\"_abc\" IssueInstant=\"2013-07-31T05:00:00Z\" Version=\"2.0\"><Issuer>http://sportngin.com</Issuer><signature>stuff</signature><Subject><NameID Format=\"urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress\">jon.phenow@sportngin.com</NameID><SubjectConfirmation Method=\"urn:oasis:names:tc:SAML:2.0:cm:bearer\"><SubjectConfirmationData InResponseTo=\"123\" NotOnOrAfter=\"2013-07-31T05:03:00Z\" Recipient=\"http://saml.acs.url\"/></SubjectConfirmation></Subject><Conditions NotBefore=\"2013-07-31T04:59:55Z\" NotOnOrAfter=\"2013-07-31T06:00:00Z\"><AudienceRestriction><Audience>http://example.com</Audience></AudienceRestriction></Conditions><AttributeStatement><Attribute Name=\"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress\"><AttributeValue>jon.phenow@sportngin.com</AttributeValue></Attribute></AttributeStatement><AuthnStatment AuthnInstant=\"2013-07-31T05:00:00Z\" SessionIndex=\"_abc\"><AuthnContext><AuthnContextClassRef>urn:federation:authentication:windows</AuthnContextClassRef></AuthnContext></AuthnStatment></Assertion></samlp:Response>"
    end
  end
end
