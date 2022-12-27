require 'rails_helper'

describe Idv::ProofingComponentsLogging do
  describe '#as_json' do
    it 'returns hash with nil values omitted' do
      proofing_components = ProofingComponent.new(document_check: Idp::Constants::Vendors::AAMVA)
      logging = described_class.new(proofing_components)

      expect(logging.as_json).to eq('document_check' => Idp::Constants::Vendors::AAMVA)
    end
  end
end
