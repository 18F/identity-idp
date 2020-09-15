require 'rails_helper'

RSpec.describe 'shared/_maintenance_window_alert.html.erb' do
  let(:start) { Time.zone.parse('2020-01-01T00:00:00Z') }
  let(:finish) { Time.zone.parse('2020-01-01T23:59:59Z') }

  before do
    allow(Figaro.env).to receive(:acuant_maintenance_window_start).and_return(start.iso8601)
    allow(Figaro.env).to receive(:acuant_maintenance_window_finish).and_return(finish.iso8601)
  end

  subject(:render_partial) do
    render(
      'shared/maintenance_window_alert',
      now: now,
    ) { 'contents of block' }
  end

  context 'during the maintenance window' do
    let(:now) { Time.zone.parse('2020-01-01T12:00:00Z') }

    it 'renders a warning and not the contents of the block' do
      render_partial

      expect(rendered).to have_content('We are currently under maintenance')

      formatted_finish = l(
        finish.in_time_zone('America/New_York'),
        format: t('time.formats.event_timestamp_with_zone'),
      )
      expect(rendered).to have_content(formatted_finish)

      expect(rendered).to_not have_content('contents of block')
    end
  end

  context 'outside the maintenance window' do
    let(:now) { Time.zone.parse('2020-01-03T00:00:00Z') }

    it 'renders the contents of the block but no warning' do
      render_partial

      expect(rendered).to have_content('contents of block')

      expect(rendered).to_not have_content('We are currently under maintenance')
    end
  end
end
