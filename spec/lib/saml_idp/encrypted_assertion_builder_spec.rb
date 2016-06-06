require 'spec_helper'

require 'saml_idp/encrypted_assertion_builder'

module SamlIdp
  describe EncryptedAssertionBuilder do
    let(:reference_id) { "abc" }
    let(:issuer_uri) { "http://sportngin.com" }
    let(:name_id) { "jon.phenow@sportngin.com" }
    let(:audience_uri) { "http://example.com" }
    let(:saml_request_id) { "123" }
    let(:saml_acs_url) { "http://saml.acs.url" }
    let(:algorithm) { :sha256 }
    let(:authn_context_classref) {
      Saml::XML::Namespaces::AuthnContext::ClassRef::PASSWORD
    }
    let(:expiry) { 3*60*60 }
    let (:encryption_opts) do
      {
        cert: Default::X509_CERTIFICATE,
        block_encryption: 'aes256-cbc',
        key_transport: 'rsa-oaep-mgf1p',
      }
    end
    subject { described_class.new(
      reference_id,
      issuer_uri,
      name_id,
      audience_uri,
      saml_request_id,
      saml_acs_url,
      algorithm,
      authn_context_classref,
      expiry
    ) }

    it "builds encrypted XML" do
      builder = described_class.new(
        reference_id,
        issuer_uri,
        name_id,
        audience_uri,
        saml_request_id,
        saml_acs_url,
        algorithm,
        authn_context_classref,
        expiry,
        encryption_opts
      )
      encrypted_xml = builder.encrypt
      encrypted_xml.should_not match(audience_uri)

      encrypted_doc = Nokogiri::XML::Document.parse(encrypted_xml)
      encrypted_data = Xmlenc::EncryptedData.new(encrypted_doc.at_xpath('//xenc:EncryptedData', Xmlenc::NAMESPACES))
      decrypted_assertion = encrypted_data.decrypt(builder.encryption_key)
      decrypted_assertion.should == subject.raw
      decrypted_assertion.should match(audience_uri)
    end
  end
end
