require 'spec_helper'

module SamlIdp
  describe SignedInfoBuilder do
    include CloudhsmMockable

    let(:reference_id) { 'abc' }
    let(:digest) { 'em8csGAWynywpe8S4nN64o56/4DosXi2XWMY6RJ6YfA=' }
    let(:algorithm) { :sha256 }

    subject do
      described_class.new(
        reference_id,
        digest,
        algorithm,
        secret_key: Default::SECRET_KEY,
        cloudhsm_key_label: nil
      )
    end

    before do
      allow(Time).to receive_messages now: Time.parse('Jul 31 2013')
    end

    it 'builds a legit raw XML file' do
      expect(subject.raw).to eq('<ds:SignedInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#"><ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"></ds:CanonicalizationMethod><ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"></ds:SignatureMethod><ds:Reference URI="#_abc"><ds:Transforms><ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"></ds:Transform><ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"></ds:Transform></ds:Transforms><ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"></ds:DigestMethod><ds:DigestValue>em8csGAWynywpe8S4nN64o56/4DosXi2XWMY6RJ6YfA=</ds:DigestValue></ds:Reference></ds:SignedInfo>')
    end

    it 'builds a legit digest of the XML file' do
      expect(subject.signed).to eq('hKLeWLRgatHcV6N5Fc8aKveqNp6Y/J4m2WSYp0awGFtsCTa/2nab32wI3du+3kuuIy59EDKeUhHVxEfyhoHUo6xTZuO2N7XcTpSonuZ/CB3WjozC2Q/9elss3z1rOC3154v5pW4puirLPRoG+Pwi8SmptxNRHczr6NvmfYmmGfo=')
    end

    context 'with cloudhsm key label' do
      before do
        mock_cloudhsm
      end

      subject do
        described_class.new(
          reference_id,
          digest,
          algorithm,
          cloudhsm_key_label: 'secret',
          secret_key: Default::SECRET_KEY
        )
      end

      it 'builds a legit raw XML file when using cloudhsm' do
        expect(subject.raw).to eq('<ds:SignedInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#"><ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"></ds:CanonicalizationMethod><ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"></ds:SignatureMethod><ds:Reference URI="#_abc"><ds:Transforms><ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"></ds:Transform><ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"></ds:Transform></ds:Transforms><ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"></ds:DigestMethod><ds:DigestValue>em8csGAWynywpe8S4nN64o56/4DosXi2XWMY6RJ6YfA=</ds:DigestValue></ds:Reference></ds:SignedInfo>')
      end

      it 'builds a legit digest of the XML file when using cloudhsm' do
        expect(subject.signed).to eq('SDFbnTosbrAThSfNMy9oq/rhDqeRZURJ7A6n17NRLKkk7uU5OrZjb8ju/UNh6NZ2gIPpqpcuJHizUm9JpkGhVoe5PpqIHFcIo74olL0TJCIWxtDIuP6Hd9xDh18mVFX4PZ4dw3KEgIw2Di3AFIhBBk8BEUvm8nZ+kutvEovySza9EIYjQd1hSse05pLKkaXZCxrxIN/53HIvxP5r7DspKvW2ma5LRO4iMDiFd42NLVvRTn7UZLqsxENnRs7lXFrm1GGGnBkExZRyr/lKBLkR5yxSg31GbX8GxNvertz0vDe078uVzSjrYyDXQyy6Mjbvj7SKhIhGcLPCw39h2OO2Zg==')
      end

      it 'raises key not found when the cloudhsm key label is not found' do
        allow(cloudhsm_session).to receive_message_chain(:find_objects, :first).and_return(nil)
        expect do
          subject.signed
        end.to raise_error(RuntimeError, 'cloudhsm key not found for label: secret')
      end

      it 'always calls session logout when opening a session with cloudhsm' do
        allow(cloudhsm_session).to receive(:logout).and_raise(RuntimeError, 'logout called')
        expect { subject.signed }.to raise_error(RuntimeError, 'logout called')
      end
    end
  end
end
