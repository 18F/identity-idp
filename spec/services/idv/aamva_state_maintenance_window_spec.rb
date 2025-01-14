require 'rails_helper'

RSpec.describe Idv::AamvaStateMaintenanceWindow do
  let(:tz) { 'America/New_York' }
  let(:eastern_time) { ActiveSupport::TimeZone[tz] }

  before do
    travel_to eastern_time.parse('2024-06-02T00:00:00')
  end

  describe '#in_maintenance_window?' do
    let(:state) { 'DC' }

    subject { described_class.in_maintenance_window?(state) }

    context 'for a state with a defined outage window' do
      it 'is true during the maintenance window' do
        travel_to(eastern_time.parse('June 2, 2024 at 1am')) do
          expect(subject).to eq(true)
        end
      end

      it 'is false outside of the maintenance window' do
        travel_to(eastern_time.parse('June 2, 2024 at 8am')) do
          expect(subject).to eq(false)
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
          eastern_time.parse('2024-06-01 04:00:00')..eastern_time.parse('2024-06-01 05:30:00'),
          eastern_time.parse('2024-05-27 01:00:00')..eastern_time.parse('2024-05-27 01:45:00'),
          eastern_time.parse('2024-05-06 01:00:00')..eastern_time.parse('2024-05-06 04:30:00'),
          eastern_time.parse('2024-05-20 01:00:00')..eastern_time.parse('2024-05-20 04:30:00'),
        ]
      end

      it 'returns all of them as ranges' do
        Time.use_zone(tz) do
          expect(subject).to eq(expected_windows)
        end
      end
    end
  end

  describe 'MAINTENANCE_WINDOWS' do
    described_class::MAINTENANCE_WINDOWS.each do |state, windows|
      it 'has a string for a key and an array as a value' do
        expect(state).to be_a(String)
        expect(windows).to be_an(Array)
      end

      windows.each do |window|
        it "consists of a valid cron expression and numeric duration (#{state})" do
          expect(window.keys).to match_array([:cron, :duration_minutes])

          # parse_cron returns nil if the expression is invalid
          cron = Fugit.parse_cron(window[:cron])
          expect(cron).to be_a(Fugit::Cron)

          expect(window[:duration_minutes]).to be_a(Numeric)
        end
      end
    end
  end
end
