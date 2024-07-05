require 'spec_helper'
module SamlIdp
  describe MetadataBuilder do

    describe '#signed' do
      it 'signs valid xml' do
        expect(Saml::XML::Document.parse(subject.signed).valid_signature?(Default::FINGERPRINT)).to be_truthy
      end

      it 'signs valid xml with a custom cert and private key' do
        subject = MetadataBuilder.new(
          SamlIdp.config,
          custom_idp_x509_cert,
          custom_idp_secret_key
        )
        expect(Saml::XML::Document.parse(subject.signed).valid_signature?(custom_idp_x509_cert_fingerprint)).to be_truthy
      end
    end

    describe '#fresh' do
      let(:schema) do
        Nokogiri::XML::Schema(File.open('spec/support/schema/saml-schema-metadata-2.0.xsd'))
      end
      let(:doc) { Nokogiri::XML(subject.fresh) }

      it 'is not empty' do
        expect(subject.fresh).not_to be_empty
      end

      it 'validates against the xsd schema' do
        expect(schema.valid?(doc)).to be true
      end
    end
  end
end
