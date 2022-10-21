require 'rails_helper'

RSpec.describe StepIndicatorStepComponent, type: :component do
  let(:title) { 'Step Name' }
  let(:status) { nil }

  subject(:rendered) do
    render_inline StepIndicatorStepComponent.new(title: title, status: status)
  end

  it 'renders step title' do
    expect(rendered).to have_content(title)
  end

  describe 'status' do
    context 'with nil status' do
      it 'renders incomplete step' do
        expect(rendered).to have_selector('.step-indicator__step')
        expect(rendered).not_to have_selector('.step-indicator__step--current')
        expect(rendered).not_to have_selector('.step-indicator__step--complete')
      end

      it 'renders accessible indicator' do
        expect(rendered).to have_text(t('step_indicator.status.not_complete'))
      end
    end

    context 'with current status' do
      let(:status) { :current }

      it 'renders current step' do
        expect(rendered).to have_selector('.step-indicator__step')
        expect(rendered).to have_selector('.step-indicator__step--current')
        expect(rendered).not_to have_selector('.step-indicator__step--complete')
      end

      it 'renders accessible indicator' do
        expect(rendered).to have_text(t('step_indicator.status.current'))
      end
    end

    context 'with complete status' do
      let(:status) { :complete }

      it 'renders complete step' do
        expect(rendered).to have_selector('.step-indicator__step')
        expect(rendered).to have_selector('.step-indicator__step--complete')
        expect(rendered).not_to have_selector('.step-indicator__step--current')
      end

      it 'renders accessible indicator' do
        expect(rendered).to have_text(t('step_indicator.status.complete'))
      end
    end
  end
end
