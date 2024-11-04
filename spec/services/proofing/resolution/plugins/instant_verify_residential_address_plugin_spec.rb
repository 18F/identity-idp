require 'rails_helper'

RSpec.describe Proofing::Resolution::Plugins::InstantVerifyResidentialAddressPlugin do
  subject(:plugin) do
    described_class.new
  end

  it 'includes ResidentialAddressPlugin' do
    expect(described_class.ancestors).to(
      include(Proofing::Resolution::Plugins::ResidentialAddressPlugin),
    )
  end

  describe '#sp_cost_token' do
    it 'returns lexis_nexis_resolution' do
      expect(plugin.sp_cost_token).to eql(:lexis_nexis_resolution)
    end
  end

  describe '#proofer' do
    before do
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
    end

    it 'returns a proofer' do
      expect(plugin.proofer).to be_a(Proofing::LexisNexis::InstantVerify::Proofer)
    end
  end
end
