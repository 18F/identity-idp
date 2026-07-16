# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProgressComponent, type: :component do
  let(:steps) { ['Account', 'Authentication', 'Verification'] }

  it 'rejects a current step outside the steps list' do
    component = described_class.new(steps: ['Identity'], current_step: 2)

    expect(component).not_to be_valid
    expect(component.errors[:current_step]).to include('must reference an existing step')
  end

  it 'rejects a substep outside its count' do
    component = described_class.new(
      steps: ['Identity'],
      current_step: 0,
      current_substep: 3,
      substep_count: 2,
    )

    expect(component).not_to be_valid
    expect(component.errors[:current_substep]).to include('must reference an existing substep')
  end

  it 'defaults the accessible label' do
    component = described_class.new(steps:, current_step: 0)

    expect(component.label).to eq(t('step_indicator.accessible_label'))
  end

  it 'renders completed, current, and upcoming steps with SR status' do
    rendered = render_inline(
      described_class.new(
        steps:,
        current_step: 1,
        current_substep: 1,
        substep_count: 2,
      ),
    )

    expect(rendered).to have_css('ads-progress')
    expect(rendered).to have_css('[data-complete="true"]', text: 'Account')
    expect(rendered).to have_css('[aria-current="step"]', text: /Authentication/)
    expect(rendered).to have_css('[aria-current="step"] .ads-progress__step-counter', text: '1/2')
    expect(rendered).to have_css('.ads-progress__step-label', text: 'Verification')
    expect(rendered).to have_css('.ads-sr-only', text: t('step_indicator.status.complete'))
    expect(rendered).to have_css('.ads-sr-only', text: t('step_indicator.status.not_complete'))
    expect(rendered).to have_css(
      '.ads-sr-only',
      text: t('step_indicator.substep', current: 1, total: 2),
    )
  end
end
