require 'spec_helper'
module SamlIdp
  describe AttributeDecorator do
    subject { described_class.new name: name,
              friendly_name: friendly_name,
              name_format: name_format,
              values: values
    }
    let(:name) { nil }
    let(:friendly_name) { nil }
    let(:name_format) { nil }
    let(:values) { nil }

    it "has a valid name" do
      expect(subject.name).to be_nil
    end

    it "has a valid friendly_name" do
      expect(subject.friendly_name).to be_nil
    end

    it "has a valid name_format" do
      expect(subject.name_format).to eq(Saml::XML::Namespaces::Formats::Attr::URI)
    end

    it "has a valid values" do
      expect(subject.values).to eq([])
    end

    describe "with values set" do
      let(:name) { "test" }
      let(:friendly_name) { "test too" }
      let(:name_format) { "some format" }
      let(:values) { :val }

      it "has a valid name" do
        expect(subject.name).to eq(name)
      end

      it "has a valid friendly_name" do
        expect(subject.friendly_name).to eq(friendly_name)
      end

      it "has a valid name_format" do
        expect(subject.name_format).to eq(name_format)
      end

      it "has a valid values" do
        expect(subject.values).to eq([values])
      end
    end
  end
end
