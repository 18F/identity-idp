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

    its(:name) { should be_nil }
    its(:friendly_name) { should be_nil }
    its(:name_format) { should == Saml::XML::Namespaces::NameFormats::URI }
    its(:values) { should == [] }

    describe "with values set" do
      let(:name) { "test" }
      let(:friendly_name) { "test too" }
      let(:name_format) { "some format" }
      let(:values) { :val }

      its(:name) { should == name }
      its(:friendly_name) { should == friendly_name }
      its(:name_format) { should == name_format }
      its(:values) { should == [values] }
    end
  end
end
