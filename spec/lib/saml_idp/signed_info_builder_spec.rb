require 'spec_helper'
module SamlIdp
  describe SignedInfoBuilder do
    let(:reference_id) { "abc" }
    let(:digest) { "em8csGAWynywpe8S4nN64o56/4DosXi2XWMY6RJ6YfA=" }
    let(:algorithm) { :sha256 }
    subject { described_class.new(
      reference_id,
      digest,
      algorithm
    ) }

    before do
      Time.stub now: Time.parse("Jul 31 2013")
    end

    it "builds a legit raw XML file" do
      subject.raw.should == "<ds:SignedInfo xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\"><ds:CanonicalizationMethod Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></ds:CanonicalizationMethod><ds:SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha256\"></ds:SignatureMethod><ds:Reference URI=\"#_abc\"><ds:Transforms><ds:Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"></ds:Transform><ds:Transform Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></ds:Transform></ds:Transforms><ds:DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha256\"></ds:DigestMethod><ds:DigestValue>em8csGAWynywpe8S4nN64o56/4DosXi2XWMY6RJ6YfA=</ds:DigestValue></ds:Reference></ds:SignedInfo>"
    end

    it "builds a legit digest of the XML file" do
      subject.signed.should == "MZd0Trzk+iQiHeMf5lKI0eXkTj5RQUBQH5j81jNNR/Ndf7Q1tIxsygcAM+CeWdt/Es8/Hvxe/nHmaXkkAB0BR5p8Pfrpv90wL1D+w6zeOLDNw9/+kn9E6Syu/2NMxrFetiVM7WwZcAJRA4WHRqxk6IIHIIf/Y3pf1tqKNWe6UgY="
    end
  end
end
