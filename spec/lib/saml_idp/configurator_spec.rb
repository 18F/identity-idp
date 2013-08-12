require 'spec_helper'
module SamlIdp
  describe Configurator do
    it { should respond_to :x509_certificate }
    it { should respond_to :secret_key }
    it { should respond_to :algorithm }
    it { should respond_to :organization_name }
    it { should respond_to :organization_url }
    it { should respond_to :base_saml_location }
    it { should respond_to :reference_id_generator }
    it { should respond_to :attribute_service_location }
    it { should respond_to :single_service_post_location }
    it { should respond_to :name_id }
    it { should respond_to :attributes }
    it { should respond_to :service_provider }

    its(:x509_certificate) { should == Default::X509_CERTIFICATE }
    its(:secret_key) { should == Default::SECRET_KEY }
    its(:algorithm) { should == :sha1 }
    its(:reference_id_generator) { should respond_to :call }

    it "can call service provider finder" do
      subject.service_provider.finder.should respond_to :call
    end

    it "can call service provider metadata persister" do
      subject.service_provider.metadata_persister.should respond_to :call
    end
  end
end
