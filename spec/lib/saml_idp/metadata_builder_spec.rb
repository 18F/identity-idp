require 'spec_helper'
module SamlIdp
  describe MetadataBuilder do
    include CloudhsmMockable
  
    it "has a valid fresh" do
      expect(subject.fresh).not_to be_empty
    end

    it "signs valid xml" do
      expect(Saml::XML::Document.parse(subject.signed).valid_signature?(Default::FINGERPRINT)).to be_truthy
    end

    it "signs valid xml with a custom cert and private key" do
      subject = MetadataBuilder.new(
        SamlIdp.config,
        custom_idp_x509_cert,
        custom_idp_secret_key
      )
      expect(Saml::XML::Document.parse(subject.signed).valid_signature?(custom_idp_x509_cert_fingerprint)).to be_truthy
    end

    it "signs valid xml with a cloudhsm key" do
      mock_cloudhsm
      subject = MetadataBuilder.new(
        SamlIdp.config,
        cloudhsm_idp_x509_cert,
        nil,
        'secret'
      )
      expect(Saml::XML::Document.parse(subject.signed).valid_signature?(cloudhsm_idp_x509_cert_fingerprint)).to be_truthy
    end

    it "includes logout element" do
      subject.configurator.single_logout_service_post_location = 'https://example.com/saml/logout'
      expect(subject.fresh).to match(
        '<SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://example.com/saml/logout"/>'
      )
    end
  end
end
