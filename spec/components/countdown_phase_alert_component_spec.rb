require 'rails_helper'

RSpec.describe CountdownPhaseAlertComponent, type: :component do
  around { |ex| freeze_time { ex.run } }

  let(:expiration) { Time.zone.now + 90.seconds }

  let(:phases_unsorted) do
    [
      { at_s: 12, classes: 'usa-alert--info',    label: '12 seconds' },
      { at_s: 0,  classes: 'usa-alert--error',   label: 'Expired' },
      { at_s: 6,  classes: 'usa-alert--warning', label: '6 seconds left' },
      { at_s: 3,  classes: 'usa-alert--warning', label: '3 seconds left' },
      { at_s: 1,  classes: 'usa-alert--warning', label: '1 second left' },
    ]
  end

  let(:phases_sorted) { phases_unsorted.sort_by { |p| p[:at_s] } }

  let(:first_displayed_phase) do
    phases_sorted.last
  end

  let(:base_opts) do
    { expiration:, phases: phases_unsorted }
  end

  it 'renders the custom element' do
    rendered = render_inline described_class.new(**base_opts)
    expect(rendered).to have_css('lg-countdown-phase-alert')
  end

  it 'renders the initial phase label' do
    rendered = render_inline described_class.new(
      **base_opts,
    )

    expected_label = first_displayed_phase[:label]
    expect(rendered).to have_css('[data-role="phase-label"]', text: expected_label)
  end

  it 'renders the initial alert classes' do
    rendered = render_inline described_class.new(
      **base_opts,
      alert_options: { class: 'margin-bottom-4' },
      countdown_options: {},
    )

    expect(rendered).to have_css('.usa-alert.margin-bottom-4.usa-alert--info')
  end

  it 'renders a hidden countdown element with an expiration' do
    rendered = render_inline described_class.new(**base_opts)
    expect(rendered).to have_css('lg-countdown[data-expiration].display-none[aria-hidden="true"]')
  end

  it 'includes base classes on data attributes' do
    rendered = render_inline described_class.new(
      **base_opts,
      alert_options: { class: 'margin-bottom-4' },
    )

    node = rendered.at_css('lg-countdown-phase-alert')

    expect(node['data-base-classes']).to eq('usa-alert margin-bottom-4')
    expect(node['data-type-classes']).to be_nil
  end

  it 'includes phases on data attributes' do
    rendered = render_inline described_class.new(
      **base_opts,
    )

    node = rendered.at_css('lg-countdown-phase-alert')

    phases   = JSON.parse(node['data-phases'])
    expected = JSON.parse(phases_sorted.to_json)

    expect(phases).to eq(expected)
  end

  it 'includes optional screen-reader region ids when provided' do
    rendered = render_inline described_class.new(
      **base_opts,
      sr_phase_region_id: 'otp-live-phase',
      sr_expiry_region_id: 'otp-live-expiry',
    )

    node = rendered.at_css('lg-countdown-phase-alert')
    expect(node['data-sr-phase-region-id']).to eq('otp-live-phase')
    expect(node['data-sr-expiry-region-id']).to eq('otp-live-expiry')
  end

  context 'alert_options passthrough' do
    it 'passes arbitrary attributes to the nested alert element' do
      rendered = render_inline described_class.new(
        **base_opts,
        alert_options: { data: { foo: 'bar' }, role: 'region', class: 'margin-bottom-4' },
      )
      expect(rendered).to have_css('.usa-alert[data-foo="bar"][role="region"]')
      expect(rendered).to have_css('.usa-alert.margin-bottom-4.usa-alert--info')
    end
  end
end
