require 'spec_helper'
module SamlIdp
  describe AssertionBuilder do
    let(:reference_id) { "abc" }
    let(:issuer_uri) { "http://sportngin.com" }
    let(:name_id) { "jon.phenow@sportngin.com" }
    let(:audience_uri) { "http://example.com" }
    let(:saml_request_id) { "123" }
    let(:saml_acs_url) { "http://saml.acs.url" }
    let(:algorithm) { :sha256 }
    subject { described_class.new(
      reference_id,
      issuer_uri,
      name_id,
      audience_uri,
      saml_request_id,
      saml_acs_url,
      algorithm
    ) }

    before do
      Time.stub now: Time.parse("Jul 31 2013")
    end

    it "builds a legit raw XML file" do
      subject.raw.should == "<Assertion xmlns=\"urn:oasis:names:tc:SAML:2.0:assertion\" ID=\"_abc\" IssueInstant=\"2013-07-31T05:00:00Z\" Version=\"2.0\"><Issuer>http://sportngin.com</Issuer><Subject><NameID Format=\"urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress\">foo@example.com</NameID><SubjectConfirmation Method=\"urn:oasis:names:tc:SAML:2.0:cm:bearer\"><SubjectConfirmationData InResponseTo=\"123\" NotOnOrAfter=\"2013-07-31T05:03:00Z\" Recipient=\"http://saml.acs.url\"></SubjectConfirmationData></SubjectConfirmation></Subject><Conditions NotBefore=\"2013-07-31T04:59:55Z\" NotOnOrAfter=\"2013-07-31T06:00:00Z\"><AudienceRestriction><Audience>http://example.com</Audience></AudienceRestriction></Conditions><AttributeStatement><Attribute Name=\"email-address\" NameFormat=\"urn:oasis:names:tc:SAML:2.0:attrname-format:uri\" FriendlyName=\"emailAddress\"><AttributeValue>foo@example.com</AttributeValue></Attribute></AttributeStatement><AuthnStatement AuthnInstant=\"2013-07-31T05:00:00Z\" SessionIndex=\"_abc\"><AuthnContext><AuthnContextClassRef>urn:oasis:names:tc:SAML:2.0:ac:classes:Password</AuthnContextClassRef></AuthnContext></AuthnStatement></Assertion>"
    end
  end
end
