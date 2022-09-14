require 'rails_helper'

describe Idv::InPersonConfig do
  let(:in_person_proofing_enabled) { false }
  let(:idv_sp_required) { false }

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
    allow(IdentityConfig.store).to receive(:idv_sp_required).and_return(idv_sp_required)
  end

  describe '.enabled_for_issuer?' do
    let(:issuer) { nil }
    subject(:enabled_for_issuer) { described_class.enabled_for_issuer?(issuer) }

    it { expect(enabled_for_issuer).to eq false }

    context 'with in person proofing enabled' do
      let(:in_person_proofing_enabled) { true }

      it { expect(enabled_for_issuer).to eq true }

      context 'with idv sp required' do
        let(:idv_sp_required) { true }

        it { expect(enabled_for_issuer).to eq false }
      end

      context 'with issuer argument' do
        let(:issuer) { 'example-issuer' }

        context 'issuer does not exist' do
          it { expect(enabled_for_issuer).to eq false }
        end

        context 'issuer has in-person proofing disabled' do
          before do
            create(:service_provider, issuer: issuer, in_person_proofing_enabled: false)
          end
          it { expect(enabled_for_issuer).to eq false }
        end

        context 'issuer has in-person proofing enabled' do
          before do
            create(:service_provider, issuer: issuer, in_person_proofing_enabled: true)
          end
          it { expect(enabled_for_issuer).to eq true }
        end
      end
    end
  end

  describe '.enabled?' do
    subject(:enabled) { described_class.enabled? }

    it { expect(enabled).to eq false }

    context 'with in person proofing enabled' do
      let(:in_person_proofing_enabled) { true }

      it { expect(enabled).to eq true }
    end
  end

  describe '.enabled_without_issuer?' do
    subject(:enabled_without_issuer) { described_class.enabled_without_issuer? }

    it { expect(enabled_without_issuer).to eq true }

    context 'with idv sp required' do
      let(:idv_sp_required) { true }

      it { expect(enabled_without_issuer).to eq false }
    end
  end
end
