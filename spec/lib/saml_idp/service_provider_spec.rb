require 'spec_helper'
module SamlIdp
  describe ServiceProvider do
    subject { described_class.new attributes }
    let(:attributes) { {} }

    it { is_expected.to respond_to :fingerprint }
    it { is_expected.to respond_to :metadata_url }
    it { is_expected.not_to be_valid }

    describe "with attributes" do
      let(:attributes) { { fingerprint: fingerprint, metadata_url: metadata_url } }
      let(:fingerprint) { Default::FINGERPRINT }
      let(:metadata_url) { "http://localhost:3000/metadata" }

      it "has a valid fingerprint" do
        expect(subject.fingerprint).to eq(fingerprint)
      end

      it "has a valid metadata_url" do
        expect(subject.metadata_url).to eq(metadata_url)
      end

      it { is_expected.to be_valid }
    end
  end
end
