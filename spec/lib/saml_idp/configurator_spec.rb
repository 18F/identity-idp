require 'spec_helper'
module SamlIdp
  describe Configurator do
    it { is_expected.to respond_to :x509_certificate }
    it { is_expected.to respond_to :secret_key }
    it { is_expected.to respond_to :algorithm }
    it { is_expected.to respond_to :organization_name }
    it { is_expected.to respond_to :organization_url }
    it { is_expected.to respond_to :base_saml_location }
    it { is_expected.to respond_to :reference_id_generator }
    it { is_expected.to respond_to :attribute_service_location }
    it { is_expected.to respond_to :single_service_post_location }
    it { is_expected.to respond_to :single_logout_service_post_location }
    it { is_expected.to respond_to :name_id }
    it { is_expected.to respond_to :attributes }
    it { is_expected.to respond_to :service_provider }

    it "has a valid x509_certificate" do
      expect(subject.x509_certificate).to eq(Default::X509_CERTIFICATE)
    end

    it "has a valid secret_key" do
      expect(subject.secret_key).to eq(Default::SECRET_KEY)
    end

    it "has a valid algorithm" do
      expect(subject.algorithm).to eq(:sha1)
    end

    it "has a valid reference_id_generator" do
      expect(subject.reference_id_generator).to respond_to :call
    end


    it "can call service provider finder" do
      expect(subject.service_provider.finder).to respond_to :call
    end

    it "can call service provider metadata persister" do
      expect(subject.service_provider.metadata_persister).to respond_to :call
    end
  end
end
