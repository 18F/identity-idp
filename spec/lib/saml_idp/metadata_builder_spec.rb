require 'spec_helper'
module SamlIdp
  describe MetadataBuilder do
    its(:fresh) { should_not be_empty }
    it "signs valid xml" do
      Saml::XML::Document.parse(subject.signed).valid_signature?(Default::FINGERPRINT).should be_true
    end
  end
end
