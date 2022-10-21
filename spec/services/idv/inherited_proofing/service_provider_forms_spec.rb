require 'rails_helper'

RSpec.describe Idv::InheritedProofing::ServiceProviderForms do
  subject do
    Class.new do
      include Idv::InheritedProofing::ServiceProviderForms
    end.new
  end

  let(:service_provider) { :va }
  let(:payload_hash) { Idv::InheritedProofing::Va::Mocks::Service::PAYLOAD_HASH }

  describe '#inherited_proofing_form_for' do
    context 'when there is a va inherited proofing request' do
      it 'returns the correct form' do
        expect(
          subject.inherited_proofing_form_for(
            service_provider,
            payload_hash: payload_hash,
          ),
        ).to \
          be_kind_of Idv::InheritedProofing::Va::Form
      end
    end

    context 'when the inherited proofing request cannot be identified' do
      let(:service_provider) { :unknown_service_provider }

      it 'raises an error' do
        expect do
          subject.inherited_proofing_form_for(service_provider, payload_hash: payload_hash)
        end.to \
          raise_error 'Inherited proofing form could not be identified'
      end
    end
  end
end
