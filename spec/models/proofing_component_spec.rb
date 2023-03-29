require 'rails_helper'

RSpec.describe ProofingComponent do
  describe '#review_eligible?' do
    subject(:review_eligible?) do
      build(:proofing_component, verified_at: verified_at).review_eligible?
    end

    context 'when verified_at is nil' do
      let(:verified_at) { nil }

      it { is_expected.to be_falsey }
    end

    context 'when verified_at is within 30 days' do
      let(:verified_at) { 15.days.ago }

      it { is_expected.to be_truthy }
    end

    context 'when verified_at is older than 30 days' do
      let(:verified_at) { 45.days.ago }

      it { is_expected.to be_falsey }
    end
  end
end
