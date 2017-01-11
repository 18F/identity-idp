require 'spec_helper'
module SamlIdp
  describe MetadataBuilder do
    it "has a valid fresh" do
      expect(subject.fresh).not_to be_empty
    end

    it "signs valid xml" do
      expect(Saml::XML::Document.parse(subject.signed).valid_signature?(Default::FINGERPRINT)).to be_truthy
    end

    it "includes logout element" do
      subject.configurator.single_logout_service_post_location = 'https://example.com/saml/logout'
      expect(subject.fresh).to match(
        '<SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://example.com/saml/logout"/>'
      )
    end
  end
end
