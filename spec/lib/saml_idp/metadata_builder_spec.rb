require 'spec_helper'
module SamlIdp
  describe MetadataBuilder do
    include CloudhsmMockable

    describe '#signed' do
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
    end

    describe '#fresh' do
      let(:schema) { Nokogiri::XML::Schema(File.open('spec/support/schema/saml-schema-metadata-2.0.xsd')) }
      let(:doc) { Nokogiri::XML(subject.fresh) }

      it "is not empty" do
        expect(subject.fresh).not_to be_empty
      end

      it "includes logout elements" do
        subject.configurator.single_logout_service_post_location = 'https://example.com/saml/logout'
        subject.configurator.remote_logout_service_post_location = 'https://example.com/saml/remote_logout'
        expect(subject.fresh.scan(/SingleLogoutService/).count).to eq(3)
        expect(subject.fresh).to match(slo_regex('HTTP-POST', 'https://example.com/saml/logout'))
        expect(subject.fresh).to match(slo_regex('HTTP-Redirect', 'https://example.com/saml/logout'))
        expect(subject.fresh).to match(slo_regex('HTTP-POST', 'https://example.com/saml/remote_logout'))
      end

      it "skips remote logout if not present" do
        subject.configurator.single_logout_service_post_location = 'https://example.com/saml/logout'
        subject.configurator.remote_logout_service_post_location = nil
        expect(subject.fresh.scan(/SingleLogoutService/).count).to eq(2)
      end

      it 'validates against the xsd schema' do
        expect(schema.valid?(doc)).to be true
      end

      def slo_regex(binding, location)
        %r{<SingleLogoutService Binding=.+#{binding}.+ Location=.+#{location}.+/>}
      end
    end
  end
end
