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
      subject.name.should be_nil
    end

    it "has a valid friendly_name" do
      subject.friendly_name.should be_nil
    end

    it "has a valid name_format" do
      subject.name_format.should == Saml::XML::Namespaces::Formats::Attr::URI
    end

    it "has a valid values" do
      subject.values.should == []
    end

    describe "with values set" do
      let(:name) { "test" }
      let(:friendly_name) { "test too" }
      let(:name_format) { "some format" }
      let(:values) { :val }

      it "has a valid name" do
        subject.name.should == name
      end

      it "has a valid friendly_name" do
        subject.friendly_name.should == friendly_name
      end

      it "has a valid name_format" do
        subject.name_format.should == name_format
      end

      it "has a valid values" do
        subject.values.should == [values]
      end

    end
  end
end
