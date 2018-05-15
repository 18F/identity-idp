require 'spec_helper'

class MockSession; end

module SamlIdp
  describe SignedInfoBuilder do
    let(:reference_id) { "abc" }
    let(:digest) { "em8csGAWynywpe8S4nN64o56/4DosXi2XWMY6RJ6YfA=" }
    let(:algorithm) { :sha256 }
    subject { described_class.new(
      reference_id,
      digest,
      algorithm,
      Default::SECRET_KEY
    ) }

    before do
      allow(Time).to receive_messages now: Time.parse("Jul 31 2013")
    end

    it "builds a legit raw XML file" do
      expect(subject.raw).to eq("<ds:SignedInfo xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\"><ds:CanonicalizationMethod Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></ds:CanonicalizationMethod><ds:SignatureMethod Algorithm=\"http://www.w3.org/2001/04/xmldsig-more#rsa-sha256\"></ds:SignatureMethod><ds:Reference URI=\"#_abc\"><ds:Transforms><ds:Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"></ds:Transform><ds:Transform Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></ds:Transform></ds:Transforms><ds:DigestMethod Algorithm=\"http://www.w3.org/2001/04/xmlenc#sha256\"></ds:DigestMethod><ds:DigestValue>em8csGAWynywpe8S4nN64o56/4DosXi2XWMY6RJ6YfA=</ds:DigestValue></ds:Reference></ds:SignedInfo>")
    end

    it "builds a legit digest of the XML file" do
      expect(subject.signed).to eq("hKLeWLRgatHcV6N5Fc8aKveqNp6Y/J4m2WSYp0awGFtsCTa/2nab32wI3du+3kuuIy59EDKeUhHVxEfyhoHUo6xTZuO2N7XcTpSonuZ/CB3WjozC2Q/9elss3z1rOC3154v5pW4puirLPRoG+Pwi8SmptxNRHczr6NvmfYmmGfo=")
    end

    it "builds a legit raw XML file when using cloudhsm" do
      mock_cloudhsm
      expect(subject.raw).to eq("<ds:SignedInfo xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\"><ds:CanonicalizationMethod Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></ds:CanonicalizationMethod><ds:SignatureMethod Algorithm=\"http://www.w3.org/2001/04/xmldsig-more#rsa-sha256\"></ds:SignatureMethod><ds:Reference URI=\"#_abc\"><ds:Transforms><ds:Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"></ds:Transform><ds:Transform Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></ds:Transform></ds:Transforms><ds:DigestMethod Algorithm=\"http://www.w3.org/2001/04/xmlenc#sha256\"></ds:DigestMethod><ds:DigestValue>em8csGAWynywpe8S4nN64o56/4DosXi2XWMY6RJ6YfA=</ds:DigestValue></ds:Reference></ds:SignedInfo>")
    end

    it "builds a legit digest of the XML file when using cloudhsm" do
      mock_cloudhsm
      expect(subject.signed).to eq('')
    end

    it "raises key not found when the cloudhsm key label is not found" do
      mock_cloudhsm
      allow(MockSession).to receive_message_chain(:find_objects, :first).and_return(nil)
      stub_const 'SamlIdp::Default::SECRET_KEY', 'secret'
      expect { subject.signed }.to raise_error(RuntimeError, 'cloudhsm key not found for label: secret')
    end

    it "always calls session logout when opening a session with cloudhsm" do
      mock_cloudhsm
      allow(MockSession).to receive(:logout).and_raise(RuntimeError, 'logout called')
      expect { subject.signed }.to raise_error(RuntimeError, 'logout called')
    end

    def mock_cloudhsm
      allow(SamlIdp).to receive_message_chain(:config, :cloudhsm_enabled).and_return(true)
      allow(SamlIdp).to receive_message_chain(:config, :pkcs11, :active_slots, :first, :open).and_yield(MockSession)
      allow(MockSession).to receive(:login).and_return(:true)
      allow(MockSession).to receive(:logout).and_return(:true)
      allow(SamlIdp).to receive_message_chain(:config, :cloudhsm_pin).and_return(true)
      allow(MockSession).to receive_message_chain(:find_objects, :first).and_return(true)
      allow(MockSession).to receive(:sign).and_return('')
    end
  end
end
