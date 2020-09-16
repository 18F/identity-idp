require 'rails_helper'

RSpec.describe MaintenanceWindow do
  subject(:maintenance_window) do
    MaintenanceWindow.new(
      start: start,
      finish: finish,
      now: now,
      display_time_zone: display_time_zone,
    )
  end

  let(:start) { '2020-01-01T00:00:00Z' }
  let(:finish) { '2020-01-01T23:59:59Z' }
  let(:now) { nil }
  let(:display_time_zone) { 'America/Los_Angeles' }

  describe '#active?' do
    context 'when now is during the maintenance window' do
      let(:now) { '2020-01-01T12:00:00Z' }
      it { expect(maintenance_window.active?).to eq(true) }
    end

    context 'when now is outside the maintenance window' do
      let(:now) { '2020-12-31T00:00:00Z' }
      it { expect(maintenance_window.active?).to eq(false) }
    end

    context 'when both start and finish are empty' do
      let(:start) { '' }
      let(:finish) { '' }

      it 'is falsey' do
        expect(maintenance_window.active?).to be_falsey
      end
    end
  end

  describe '#start' do
    it 'is formatted in the display_time_zone' do
      expect(maintenance_window.start.time_zone.name).to eq(display_time_zone)
    end

    context 'with an empty value' do
      let(:start) { '' }
      it { expect(maintenance_window.start).to eq(nil) }
    end
  end

  describe '#finish' do
    it 'is formatted in the display_time_zone' do
      expect(maintenance_window.finish.time_zone.name).to eq(display_time_zone)
    end

    context 'with an empty value' do
      let(:finish) { '' }
      it { expect(maintenance_window.finish).to eq(nil) }
    end
  end
end
