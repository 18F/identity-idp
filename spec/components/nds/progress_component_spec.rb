require 'rails_helper'

RSpec.describe NDS::ProgressComponent, type: :component do
  let(:steps) { %w[Create\ account Secure Connect] }

  def render_progress(**opts)
    render_inline(NDS::ProgressComponent.new(steps:, current_step: 1, **opts))
  end

  it 'renders the nds-progress custom element with unprefixed classes' do
    rendered = render_progress
    expect(rendered).to have_css('nds-progress.progress')
    expect(rendered).to have_css('.progress__scroll > ol.progress__stepper > li')
    expect(rendered).to have_css('.progress__step', count: 3)
    expect(rendered).to have_css('.progress__step-surface .progress__step-label', count: 3)
  end

  it 'marks the active step with aria-current=step' do
    rendered = render_progress(current_step: 1)
    active = rendered.css('.progress__step[aria-current="step"]')
    expect(active.length).to eq(1)
    expect(active.first).to have_text('Secure')
  end

  it 'marks completed steps with data-complete=true and a check icon' do
    rendered = render_progress(current_step: 2)
    complete = rendered.css('.progress__step[data-complete="true"]')
    expect(complete.length).to eq(2) # steps 0 and 1
    expect(rendered).to have_css(
      '.progress__step[data-complete="true"] .progress__step-check',
      count: 2,
    )
  end

  it 'does not mark future steps complete or current' do
    rendered = render_progress(current_step: 0)
    expect(rendered).not_to have_css('.progress__step[data-complete="true"]')
    expect(rendered.css('.progress__step[aria-current="step"]').length).to eq(1)
  end

  it 'renders a substep counter on the active step when substeps given' do
    rendered = render_progress(current_step: 1, current_substep: 2, substep_count: 4)
    expect(rendered).to have_css(
      '.progress__step[aria-current="step"] .progress__step-counter',
      text: '2 / 4',
    )
  end

  it 'renders sr-only status + substep text with the sr-only class' do
    rendered = render_progress(current_step: 1, current_substep: 2, substep_count: 4)
    expect(rendered).to have_css('span.sr-only')
  end

  it 'uses the given aria label' do
    rendered = render_progress(label: 'Custom label')
    expect(rendered).to have_css('ol.progress__stepper[aria-label="Custom label"]')
  end

  it 'emits the progress, progress__step, and sr-only classes' do
    rendered = render_progress(current_step: 1, current_substep: 1, substep_count: 3)
    expect(rendered).to have_css('nds-progress.progress')
    expect(rendered).to have_css('.progress__step')
    expect(rendered).to have_css('span.sr-only')
  end

  it 'validates steps presence' do
    expect do
      render_inline(NDS::ProgressComponent.new(steps: [], current_step: 0))
    end.to raise_error(ActiveModel::ValidationError)
  end

  it 'validates current_step is within steps' do
    expect do
      render_inline(NDS::ProgressComponent.new(steps:, current_step: 9))
    end.to raise_error(ActiveModel::ValidationError)
  end

  it 'validates substep is within range' do
    expect do
      render_inline(
        NDS::ProgressComponent.new(steps:, current_step: 1, current_substep: 9, substep_count: 4),
      )
    end.to raise_error(ActiveModel::ValidationError)
  end
end
