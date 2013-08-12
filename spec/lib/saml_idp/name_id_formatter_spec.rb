require 'spec_helper'
module SamlIdp
  describe NameIdFormatter do
    subject { described_class.new list }

    describe "with one item" do
      let(:list) { { email_address: ->() { "foo@example.com" } } }

      its(:all) { should == ["urn:oasis:names:tc:SAML:2.0:nameid-format:emailAddress"] }
    end

    describe "with hash describing versions" do
      let(:list) {
        {
          "1.1" => { email_address: -> {} },
          "2.0" => { undefined: -> {} },
        }
      }

      its(:all) {
        should == [
          "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress",
          "urn:oasis:names:tc:SAML:2.0:nameid-format:undefined",
        ]
      }
    end

    describe "with actual list" do
      let(:list) { [:email_address, :undefined] }

      its(:all) {
        should == [
          "urn:oasis:names:tc:SAML:2.0:nameid-format:emailAddress",
          "urn:oasis:names:tc:SAML:2.0:nameid-format:undefined",
        ]
      }
    end
  end
end
