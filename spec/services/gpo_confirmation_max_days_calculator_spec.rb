require 'rails_helper'

RSpec.describe GpoConfirmationMaxDaysCalculator do
  describe '.max_days_for_state' do
    before do
      allow(IdentityConfig.store).to receive(:usps_confirmation_max_days_contiguous_states)
        .and_return(21)
      allow(IdentityConfig.store).to receive(:usps_confirmation_max_days).and_return(30)
    end

    context 'when the state is a contiguous US state' do
      it 'returns usps_confirmation_max_days_contiguous_states' do
        expect(described_class.max_days_for_state('VA')).to eq(21)
      end
    end

    context 'when the state is DC' do
      it 'returns usps_confirmation_max_days_contiguous_states' do
        expect(described_class.max_days_for_state('DC')).to eq(21)
      end
    end

    context 'when the state is a non-contiguous US state (AK, HI)' do
      it 'returns usps_confirmation_max_days' do
        expect(described_class.max_days_for_state('AK')).to eq(30)
        expect(described_class.max_days_for_state('HI')).to eq(30)
      end
    end

    context 'when the state is a US territory' do
      it 'returns usps_confirmation_max_days' do
        %w[PR GU AS MP VI].each do |territory|
          expect(described_class.max_days_for_state(territory)).to eq(30)
        end
      end
    end

    context 'when the state is nil' do
      it 'returns usps_confirmation_max_days' do
        expect(described_class.max_days_for_state(nil)).to eq(30)
      end
    end

    context 'when the state is not a recognized code' do
      it 'returns usps_confirmation_max_days' do
        expect(described_class.max_days_for_state('XX')).to eq(30)
      end
    end
  end
end
