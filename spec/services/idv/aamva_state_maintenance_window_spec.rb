require 'rails_helper'

RSpec.describe Idv::AamvaStateMaintenanceWindow do
  let(:tz) { 'America/New_York' }

  before do
    travel_to Date.new(2024, 6, 2)
  end

  describe '#in_maintenance_window?' do
    let(:state) { 'DC' }

    subject { described_class.in_maintenance_window?(state) }

    context 'for a state with a defined outage window' do
      it 'is true during the maintenance window' do
        Time.use_zone(tz) do
          travel_to(Time.parse('June 2, 2024 at 1am')) do
            expect(subject).to eq(true)
          end
        end
      end

      it 'is false outside of the maintenance window' do
        Time.use_zone(tz) do
          travel_to(Time.zone.parse('today 08:00')) do
            expect(subject).to eq(false)
          end
        end
      end
    end

    context 'for a state without a defined outage window' do
      let(:state) { 'LG' }

      it 'returns false without an exception' do
        expect(subject).to eq(false)
      end
    end
  end

  # This should maybe be private, but for now it's handy to be able to fetch.
  # And I can see applications for it.
  describe '.windows_for_state' do
    subject { described_class.windows_for_state(state) }

    context 'for a state with no entries' do
      let(:state) { 'LG' }

      it 'returns an empty array for a state with no entries' do
        expect(subject).to eq([])
      end
    end

    context 'for a state with multiple overlapping windows' do
      let(:state) { 'CA' }
      let(:expected_windows) do
        [
          Time.parse('2024-06-01 04:00:00 -0400')..Time.parse('2024-06-01 05:30:00 -0400'),
          Time.parse('2024-05-27 01:00:00 -0400')..Time.parse('2024-05-27 01:45:00 -0400'),
          Time.parse('2024-05-06 01:00:00 -0400')..Time.parse('2024-05-06 04:30:00 -0400'),
          Time.parse('2024-05-20 01:00:00 -0400')..Time.parse('2024-05-20 04:30:00 -0400'),
        ]
      end

      it 'returns all of them as ranges' do
        Time.use_zone(tz) do
          expect(subject).to eq(expected_windows)
        end
      end
    end
  end
end
