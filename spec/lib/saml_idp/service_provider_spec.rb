require 'spec_helper'
module SamlIdp
  describe ServiceProvider do
    subject { described_class.new attributes }
    let(:attributes) { {} }

    it { should respond_to :fingerprint }
    it { should respond_to :metadata_url }
    it { should_not be_valid }

    describe "with attributes" do
      let(:attributes) { { fingerprint: fingerprint, metadata_url: metadata_url } }
      let(:fingerprint) { Default::FINGERPRINT }
      let(:metadata_url) { "http://localhost:3000/metadata" }

      its(:fingerprint) { should == fingerprint }
      its(:metadata_url) { should == metadata_url }
      it { should be_valid }
    end
  end
end
